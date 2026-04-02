#!/usr/bin/env python3
"""Safe corpus cleanup pass for OCR/DOCX artifacts.

- Input: assets/odu_content_patched.json
- Output: build/odu_content_cleaned.json
- Publish: assets/odu_content_patched.json
- Does NOT touch assets/odu_content.json
"""

from __future__ import annotations

import datetime as dt
import json
import re
import shutil
import unicodedata
from pathlib import Path
from typing import Dict, List, Tuple

ROOT = Path(__file__).resolve().parents[1]
INPUT_JSON = ROOT / "assets" / "odu_content_patched.json"
OUTPUT_JSON = ROOT / "build" / "odu_content_cleaned.json"
PUBLISHED_JSON = ROOT / "assets" / "odu_content_patched.json"
REPORT_MD = ROOT / "build" / "odu_cleanup_report.md"
DIFF_MD = ROOT / "build" / "odu_cleanup_diff.md"


def _fold_upper(text: str) -> str:
    s = unicodedata.normalize("NFD", text)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    s = s.upper()
    s = re.sub(r"\s+", " ", s).strip()
    return s


HEADING_PREFIXES_FOLDED = {
    "REZO",
    "SUYERE",
    "EN ESTE ODU NACE",
    "DESCRIPCION DEL ODU",
    "OBRAS DEL ODU",
    "DICE IFA",
    "EWES DEL ODU",
    "REFRANES DEL ODU",
    "ESHU-ELEGBA DEL ODU",
    "ESHU ELEGBA DEL ODU",
    "HISTORIAS O PATAKINES DEL ODU",
}


def is_preserved_heading_line(line: str) -> bool:
    t = line.strip()
    if not t:
        return False
    folded = _fold_upper(t)
    for prefix in HEADING_PREFIXES_FOLDED:
        if folded.startswith(prefix):
            return True
    return False


def subn_with_count(pattern: re.Pattern[str], repl, text: str) -> Tuple[str, int]:
    new_text, n = pattern.subn(repl, text)
    return new_text, n


def cleanup_line(line: str, counts: Dict[str, int]) -> str:
    # Keep heading lines exactly unchanged.
    if is_preserved_heading_line(line):
        return line.rstrip("\n")

    s = line.rstrip("\n")

    # A) whitespace cleanup in-line
    s2 = s.rstrip()
    if s2 != s:
        counts["whitespace"] += 1
        s = s2

    s2, n = subn_with_count(re.compile(r" {3,}"), " ", s)
    if n:
        counts["whitespace"] += n
        s = s2

    # D) quote normalization (conservative)
    s2 = s
    quote_map = {
        "“": '"',
        "”": '"',
        "„": '"',
        "‟": '"',
        "«": '"',
        "»": '"',
        "‘": "'",
        "’": "'",
        "‚": "'",
    }
    for src, dst in quote_map.items():
        if src in s2:
            cnt = s2.count(src)
            s2 = s2.replace(src, dst)
            counts["quotes"] += cnt
    if s2 != s:
        s = s2

    # E) targeted hyphen cleanup
    s2, n = subn_with_count(
        re.compile(r"\bOrisha\s*-\s*Nla\b", re.IGNORECASE), "Orisha-Nla", s
    )
    if n:
        counts["hyphen_cleanup"] += n
        s = s2

    s2, n = subn_with_count(
        re.compile(r"\bOricha\s*-\s*Nla\b", re.IGNORECASE), "Orisha-Nla", s
    )
    if n:
        counts["hyphen_cleanup"] += n
        s = s2

    s2, n = subn_with_count(
        re.compile(r"\bEshu\s*-\s*Elegba\b", re.IGNORECASE), "Eshu-Elegba", s
    )
    if n:
        counts["hyphen_cleanup"] += n
        s = s2

    # B) punctuation spacing
    s2, n = subn_with_count(re.compile(r"\s+([,.;:!?])"), r"\1", s)
    if n:
        counts["punctuation"] += n
        s = s2

    # Add missing space after punctuation when safe (avoid decimals like 3.14)
    def _punct_space_repl(m: re.Match[str]) -> str:
        left = m.group(1)
        right = m.group(2)
        if left == "." and right.isdigit() and m.start() > 0:
            prev = s[m.start() - 1]
            if prev.isdigit():
                return m.group(0)
        return f"{left} {right}"

    s2, n = subn_with_count(
        re.compile(r'([,.;:!?])([^\s\]\)\}"\'])'), _punct_space_repl, s
    )
    if n:
        counts["punctuation"] += n
        s = s2

    # C) OCR numeric artifacts (safe patterns only)
    s2, n = subn_with_count(
        re.compile(r"([A-Za-zÁÉÍÓÚÜÑáéíóúüñ])(\d{2,4})(?=\s+[A-Za-zÁÉÍÓÚÜÑáéíóúüñ])"),
        r"\1",
        s,
    )
    if n:
        counts["numeric_artifacts"] += n
        s = s2

    s2, n = subn_with_count(
        re.compile(r"([.!?;:)\]])(\d{2,4})(?=\s*$)"), r"\1", s
    )
    if n:
        counts["numeric_artifacts"] += n
        s = s2

    # F) OCR character artifacts (conservative)
    s2, n = subn_with_count(re.compile(r"([.,;:])\1{1,}"), r"\1", s)
    if n:
        counts["ocr_char_fixes"] += n
        s = s2

    s2, n = subn_with_count(re.compile(r"\b0fo\b"), "Ofo", s)
    if n:
        counts["ocr_char_fixes"] += n
        s = s2

    # G) capitalization cleanup (very conservative)
    def _cap_after_punct(m: re.Match[str]) -> str:
        return f"{m.group(1)}{m.group(2).upper()}"

    s2, n = subn_with_count(
        re.compile(r"([.!?]\s+)([a-záéíóúüñ])"), _cap_after_punct, s
    )
    if n:
        counts["capitalization"] += n
        s = s2

    return s


def cleanup_text(text: str, counts: Dict[str, int]) -> str:
    lines = text.splitlines()
    cleaned_lines = [cleanup_line(line, counts) for line in lines]
    out = "\n".join(cleaned_lines)

    # A) normalize max two consecutive blank lines
    out2, n = subn_with_count(re.compile(r"\n{3,}"), "\n\n", out)
    if n:
        counts["whitespace"] += n
        out = out2

    return out


def main() -> None:
    if not INPUT_JSON.exists():
        raise SystemExit(f"Missing input JSON: {INPUT_JSON}")

    data = json.loads(INPUT_JSON.read_text(encoding="utf-8"))
    odu_map = data.get("odu")
    if not isinstance(odu_map, dict):
        raise SystemExit("Invalid schema: expected top-level 'odu' object")

    counts = {
        "whitespace": 0,
        "punctuation": 0,
        "numeric_artifacts": 0,
        "quotes": 0,
        "hyphen_cleanup": 0,
        "ocr_char_fixes": 0,
        "capitalization": 0,
    }

    odus_processed = 0
    fields_changed = 0
    changed_by_odu: Dict[str, int] = {}
    diff_rows: List[Tuple[str, str, str, str, int, int]] = []

    for odu_key, odu_entry in odu_map.items():
        if not isinstance(odu_entry, dict):
            continue
        content = odu_entry.get("content")
        if not isinstance(content, dict):
            continue

        odus_processed += 1
        entry_changes = 0

        for field_key, value in list(content.items()):
            if not isinstance(value, str):
                continue

            before = value
            after = cleanup_text(before, counts)
            if before != after:
                content[field_key] = after
                fields_changed += 1
                entry_changes += 1
                diff_rows.append(
                    (
                        str(odu_key),
                        str(field_key),
                        before[:280].replace("\n", "\\n"),
                        after[:280].replace("\n", "\\n"),
                        len(before),
                        len(after),
                    )
                )

        if entry_changes:
            changed_by_odu[str(odu_key)] = entry_changes

    # Validate same odù count + json serializable
    original_count = len(odu_map)

    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    shutil.copy2(OUTPUT_JSON, PUBLISHED_JSON)

    # Re-parse validation
    parsed = json.loads(OUTPUT_JSON.read_text(encoding="utf-8"))
    parsed_count = len(parsed.get("odu", {})) if isinstance(parsed.get("odu"), dict) else -1

    top20 = sorted(changed_by_odu.items(), key=lambda x: x[1], reverse=True)[:20]

    report_lines = [
        "# Odù Cleanup Report",
        "",
        f"- Generated UTC: `{dt.datetime.utcnow().replace(microsecond=0).isoformat()}Z`",
        f"- Input: `{INPUT_JSON}`",
        f"- Output (build): `{OUTPUT_JSON}`",
        f"- Published to patched asset: `{PUBLISHED_JSON}`",
        "- `assets/odu_content.json` modified: `false`",
        "",
        "## Totals",
        "",
        f"- Total odù processed: **{odus_processed}**",
        f"- Total text fields changed: **{fields_changed}**",
        f"- Odù count before: **{original_count}**",
        f"- Odù count after: **{parsed_count}**",
        "",
        "## Cleanup Counts By Type",
        "",
        f"- whitespace: **{counts['whitespace']}**",
        f"- punctuation: **{counts['punctuation']}**",
        f"- numeric artifacts: **{counts['numeric_artifacts']}**",
        f"- quotes: **{counts['quotes']}**",
        f"- hyphen cleanup: **{counts['hyphen_cleanup']}**",
        f"- OCR character fixes: **{counts['ocr_char_fixes']}**",
        f"- capitalization cleanup: **{counts['capitalization']}**",
        "",
        "## Top 20 Most Changed Odù Keys",
        "",
    ]

    if top20:
        for k, n in top20:
            report_lines.append(f"- {k}: {n} changed fields")
    else:
        report_lines.append("- None")

    REPORT_MD.write_text("\n".join(report_lines).rstrip() + "\n", encoding="utf-8")

    diff_lines = [
        "# Odù Cleanup Diff",
        "",
        f"- Changed fields: **{len(diff_rows)}**",
        "",
    ]

    for idx, (odu_key, field_key, before_prev, after_prev, b_len, a_len) in enumerate(diff_rows):
        if idx >= 600:
            diff_lines.append(f"... truncated {len(diff_rows) - 600} additional changed fields")
            break
        diff_lines.extend(
            [
                f"## {odu_key} / {field_key}",
                "",
                f"- Length: `{b_len} -> {a_len}`",
                "- Before:",
                "```text",
                before_prev,
                "```",
                "- After:",
                "```text",
                after_prev,
                "```",
                "",
            ]
        )

    DIFF_MD.write_text("\n".join(diff_lines).rstrip() + "\n", encoding="utf-8")

    print(f"Total odù processed: {odus_processed}")
    print(f"Total text fields changed: {fields_changed}")
    print(f"Odù count before: {original_count}")
    print(f"Odù count after: {parsed_count}")
    print(f"Wrote: {OUTPUT_JSON}")
    print(f"Wrote: {REPORT_MD}")
    print(f"Wrote: {DIFF_MD}")
    print(f"Published: {PUBLISHED_JSON}")


if __name__ == "__main__":
    main()
