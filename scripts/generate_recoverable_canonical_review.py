#!/usr/bin/env python3
"""Generate focused human-review packet for recoverable_canonical candidates."""

from __future__ import annotations

import json
import re
import unicodedata
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
IN_MISSING_MD = ROOT / "build" / "odu_missing_candidates.md"
IN_COVERAGE_CSV = ROOT / "build" / "odu_family_coverage_report.csv"
IN_BOUNDARY_AUDIT_MD = ROOT / "build" / "odu_boundary_audit.md"
IN_IMPORT_UNMATCHED_MD = ROOT / "build" / "odu_import_unmatched.md"
IN_COLLAPSED_JSON = ROOT / "build" / "odu_content_v2_collapsed.json"

OUT_MD = ROOT / "build" / "recoverable_canonical_review.md"
OUT_JSON = ROOT / "build" / "recoverable_canonical_review.json"


FAMILY_MAP: Dict[str, str] = {
    "OGBE": "OGBE",
    "EJIOGBE": "OGBE",
    "OYEKUN": "OYEKUN",
    "OYEKU": "OYEKUN",
    "IWORI": "IWORI",
    "ODI": "ODI",
    "IROSO": "IROSO",
    "IROSUN": "IROSO",
    "OJUANI": "OWONRIN",
    "OWONRIN": "OWONRIN",
    "OBARA": "OBARA",
    "OKANA": "OKANRAN",
    "OKANRAN": "OKANRAN",
    "OGUNDA": "OGUNDA",
    "OSA": "OSA",
    "IKA": "IKA",
    "OTRUPON": "OTURUPON",
    "OTRUPON": "OTURUPON",
    "OTURUPO": "OTURUPON",
    "OTURUPON": "OTURUPON",
    "OTUURUPON": "OTURUPON",
    "OTURA": "OTURA",
    "IRETE": "IRETE",
    "OSHE": "OSE",
    "OSE": "OSE",
    "OFUN": "OFUN",
}


STATE_TOKENS = {
    "OSOBO",
    "IRE",
    "IKU",
    "ARUN",
    "OFO",
    "OGU",
    "EYO",
    "AYE",
    "ARIKU",
    "OWO",
    "ONA",
}


@dataclass
class Candidate:
    family_heading: str
    heading: str
    source_file: str
    reason: str
    score: int


def normalize_upper(text: str) -> str:
    s = unicodedata.normalize("NFD", text or "")
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    s = s.upper()
    s = re.sub(r"[_\-]", " ", s)
    s = re.sub(r"[^A-Z0-9\s/]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def heading_tokens(heading: str) -> List[str]:
    toks = normalize_upper(heading).split()
    if toks and toks[0] == "BABA":
        toks = toks[1:]
    return toks


def mapped_family_tokens(tokens: List[str]) -> List[str]:
    return [FAMILY_MAP[t] for t in tokens if t in FAMILY_MAP]


def has_repeated_family(tokens: List[str]) -> bool:
    seen = set()
    for fam in mapped_family_tokens(tokens):
        if fam in seen:
            return True
        seen.add(fam)
    return False


def has_odu_x_odu_y_pattern(tokens: List[str]) -> bool:
    return len(tokens) >= 4 and tokens[0] in FAMILY_MAP and tokens[2] in FAMILY_MAP


def canonical_guess(heading: str) -> Optional[str]:
    toks = heading_tokens(heading)
    if not toks:
        return None
    if toks == ["EJIOGBE"]:
        return "OGBE MEJI"
    if len(toks) == 2 and toks[1] == "MEJI" and toks[0] in FAMILY_MAP:
        return f"{FAMILY_MAP[toks[0]]} MEJI"
    if len(toks) == 2 and toks[0] in FAMILY_MAP and toks[1] in FAMILY_MAP:
        return f"{FAMILY_MAP[toks[0]]} {FAMILY_MAP[toks[1]]}"
    return None


def parse_recoverable_canonical(md_path: Path) -> List[Candidate]:
    text = md_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    current_family = ""
    in_canonical = False
    out: List[Candidate] = []

    for line in lines:
        t = line.strip()
        if t.startswith("## "):
            current_family = t[3:].strip()
            in_canonical = False
            continue
        if t == "### recoverable_canonical":
            in_canonical = True
            continue
        if t.startswith("### ") and t != "### recoverable_canonical":
            in_canonical = False
            continue
        if not in_canonical or not t.startswith("- "):
            continue
        if t == "- None":
            continue

        m = re.match(
            r"^- `(.+?)` \| source: `(.+?)` \| reason: `(.+?)` \| score: (-?\d+)$",
            t,
        )
        if not m:
            continue
        out.append(
            Candidate(
                family_heading=current_family,
                heading=m.group(1).strip(),
                source_file=m.group(2).strip(),
                reason=m.group(3).strip(),
                score=int(m.group(4)),
            )
        )
    return out


def load_docx_paragraphs(path: Path) -> List[str]:
    try:
        from docx import Document  # type: ignore

        doc = Document(str(path))
        return [(p.text or "").replace("\u00A0", " ").rstrip() for p in doc.paragraphs]
    except Exception:
        with zipfile.ZipFile(path) as zf:
            xml = zf.read("word/document.xml")
        root = ET.fromstring(xml)
        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
        out: List[str] = []
        for p in root.findall(".//w:p", ns):
            txt = "".join((t.text or "") for t in p.findall(".//w:t", ns))
            out.append(txt.replace("\u00A0", " ").rstrip())
        return out


def find_context(
    source_file: str,
    heading: str,
    *,
    before_chars: int = 400,
    after_chars: int = 1200,
) -> Tuple[str, str, bool]:
    path = ROOT / source_file
    if not path.exists():
        return "", "", False
    paras = load_docx_paragraphs(path)
    target = normalize_upper(heading)

    hit_idx: Optional[int] = None
    for i, p in enumerate(paras):
        if normalize_upper(p) == target:
            hit_idx = i
            break
    if hit_idx is None:
        for i, p in enumerate(paras):
            pn = normalize_upper(p)
            if target and target in pn:
                hit_idx = i
                break
    if hit_idx is None:
        return "", "", False

    joined = "\n".join(paras)
    pos = 0
    start = 0
    for i, p in enumerate(paras):
        if i == hit_idx:
            start = pos
            break
        pos += len(p) + 1

    before = joined[max(0, start - before_chars) : start]
    after = joined[start : start + after_chars]
    return before, after, True


def main() -> None:
    for p in [
        IN_MISSING_MD,
        IN_COVERAGE_CSV,
        IN_BOUNDARY_AUDIT_MD,
        IN_IMPORT_UNMATCHED_MD,
        IN_COLLAPSED_JSON,
    ]:
        if not p.exists():
            raise SystemExit(f"Missing required input: {p}")

    candidates = parse_recoverable_canonical(IN_MISSING_MD)

    collapsed = json.loads(IN_COLLAPSED_JSON.read_text(encoding="utf-8"))
    odus = collapsed.get("odus", [])
    canonical_set = {normalize_upper(str(x.get("canonical_key", ""))) for x in odus}
    canonical_set.discard("")

    reviewed: List[dict] = []
    accept = reject = needs = 0

    for c in candidates:
        norm_heading = normalize_upper(c.heading)
        toks = heading_tokens(c.heading)
        guess = canonical_guess(c.heading)
        guess_norm = normalize_upper(guess or "")
        close_exists = bool(guess_norm and guess_norm in canonical_set)

        before, after, found = find_context(c.source_file, c.heading)

        rule_checks = {
            "no_state_tokens": not bool(set(toks) & STATE_TOKENS),
            "canonical_meji_or_pair_shape": guess is not None,
            "token_count_lte_3": len(toks) <= 3,
            "no_repeated_family": not has_repeated_family(toks),
            "no_explanatory_tail": len(toks) <= 3 and not has_odu_x_odu_y_pattern(toks),
        }
        pass_reason = (
            "passed rules: no_state_tokens, canonical_shape, <=3 tokens, no repeated family, no explanatory tail"
        )

        if not found:
            recommendation = "NEEDS_MANUAL_DECISION"
            rec_reason = "heading_not_found_in_source_docx"
            needs += 1
        elif guess is None:
            recommendation = "NEEDS_MANUAL_DECISION"
            rec_reason = "cannot_guess_canonical"
            needs += 1
        elif close_exists:
            recommendation = "REJECT_AS_ALIAS"
            rec_reason = "close canonical key already exists"
            reject += 1
        else:
            recommendation = "ACCEPT_AS_NEW_CANONICAL"
            rec_reason = "canonical shape and no close canonical key found"
            accept += 1

        reviewed.append(
            {
                "heading": c.heading,
                "normalized_heading": norm_heading,
                "guessed_canonical_odu": guess,
                "source_file": c.source_file,
                "before_400": before,
                "after_1200": after,
                "passed_rules_explanation": pass_reason,
                "rule_checks": rule_checks,
                "close_canonical_exists": close_exists,
                "recommendation": recommendation,
                "recommendation_reason": rec_reason,
                "original_reason": c.reason,
                "score": c.score,
                "context_found": found,
            }
        )

    payload = {
        "source_files": {
            "missing_candidates_md": str(IN_MISSING_MD),
            "coverage_csv": str(IN_COVERAGE_CSV),
            "boundary_audit_md": str(IN_BOUNDARY_AUDIT_MD),
            "import_unmatched_md": str(IN_IMPORT_UNMATCHED_MD),
            "collapsed_json": str(IN_COLLAPSED_JSON),
        },
        "total_reviewed": len(reviewed),
        "accept_count": accept,
        "reject_count": reject,
        "needs_manual_decision_count": needs,
        "items": reviewed,
    }
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    md_lines: List[str] = [
        "# Recoverable Canonical Review",
        "",
        f"- Total reviewed: **{len(reviewed)}**",
        f"- ACCEPT_AS_NEW_CANONICAL: **{accept}**",
        f"- REJECT_AS_ALIAS: **{reject}**",
        f"- NEEDS_MANUAL_DECISION: **{needs}**",
        "",
    ]

    for item in reviewed:
        md_lines.append(f"## {item['heading']}")
        md_lines.append(f"- normalized_heading: `{item['normalized_heading']}`")
        md_lines.append(f"- guessed_canonical_odu: `{item['guessed_canonical_odu']}`")
        md_lines.append(f"- source_file: `{item['source_file']}`")
        md_lines.append(f"- passed_rules: {item['passed_rules_explanation']}")
        md_lines.append(f"- close_canonical_exists: `{item['close_canonical_exists']}`")
        md_lines.append(f"- recommendation: **{item['recommendation']}**")
        md_lines.append(f"- recommendation_reason: `{item['recommendation_reason']}`")
        md_lines.append("- context_before_400:")
        md_lines.append("")
        md_lines.append("```text")
        md_lines.append((item["before_400"] or "").strip())
        md_lines.append("```")
        md_lines.append("- context_after_1200:")
        md_lines.append("")
        md_lines.append("```text")
        md_lines.append((item["after_1200"] or "").strip())
        md_lines.append("```")
        md_lines.append("")

    OUT_MD.write_text("\n".join(md_lines).rstrip() + "\n", encoding="utf-8")

    print(f"total reviewed: {len(reviewed)}")
    print(f"accept count: {accept}")
    print(f"reject count: {reject}")
    print(f"needs_manual_decision count: {needs}")
    print(f"Wrote: {OUT_MD}")
    print(f"Wrote: {OUT_JSON}")


if __name__ == "__main__":
    main()

