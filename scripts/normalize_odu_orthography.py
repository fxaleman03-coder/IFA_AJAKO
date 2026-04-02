#!/usr/bin/env python3
"""Normalize Yoruba/Afro-Cuban religious orthography in patched Odù content.

Safety:
- Reads assets/odu_content_patched.json
- Writes build/odu_content_normalized.json
- Copies build result to assets/odu_content_patched.json
- Does NOT modify assets/odu_content.json
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
OUTPUT_JSON = ROOT / "build" / "odu_content_normalized.json"
REPORT_MD = ROOT / "build" / "odu_normalization_report.md"
DIFF_MD = ROOT / "build" / "odu_normalization_diff.md"
PUBLISH_JSON = ROOT / "assets" / "odu_content_patched.json"


HEADING_PATTERNS = [
    re.compile(r"^\s*REZO\s*[:\-–—\.]?\s*$", re.IGNORECASE),
    re.compile(r"^\s*SUYERE\s*[:\-–—\.]?\s*$", re.IGNORECASE),
    re.compile(r"^\s*OBRAS\s+DEL\s+OD(?:U|O|Ù)\s*[:\-–—\.]?\s*$", re.IGNORECASE),
    re.compile(r"^\s*DICE\s+IF(?:Á|A)\s*[:\-–—\.]?\s*$", re.IGNORECASE),
    re.compile(r"^\s*EWES\s+DEL\s+OD(?:U|O|Ù)\s*[:\-–—\.]?\s*$", re.IGNORECASE),
    re.compile(r"^\s*REFRANES\s+DEL\s+OD(?:U|O|Ù)\s*[:\-–—\.]?\s*$", re.IGNORECASE),
    re.compile(r"^\s*ESHU[\s\-–—]*ELEGBA\s+DEL\s+OD(?:U|O|Ù)\s*[:\-–—\.]?\s*$", re.IGNORECASE),
    re.compile(
        r"^\s*HISTORIAS?\s+O\s+PATAK(?:I|Í)N(?:E|É)?S\s+DEL\s+OD(?:U|O|Ù)\s*[:\-–—\.]?\s*$",
        re.IGNORECASE,
    ),
]


def is_heading_line(line: str) -> bool:
    t = line.strip()
    if not t:
        return False
    return any(p.match(t) for p in HEADING_PATTERNS)


def case_preserving_replace(word_lower: str, lower_replacement: str, title_replacement: str, upper_replacement: str):
    def _repl(match: re.Match[str]) -> str:
        token = match.group(0)
        if token.isupper():
            return upper_replacement
        if token[0].isupper():
            return title_replacement
        return lower_replacement

    return _repl


def normalize_orisha_variant(match: re.Match[str]) -> str:
    token = match.group(0)
    lower = unicodedata.normalize("NFD", token)
    lower = "".join(ch for ch in lower if unicodedata.category(ch) != "Mn")
    lower = lower.lower()
    plural = lower.endswith("s")

    if token.isupper():
        return "ORISHAS" if plural else "ORISHA"
    if token[0].isupper():
        return "Orishas" if plural else "Orisha"
    return "orishas" if plural else "orisha"


def normalize_text(text: str, counts: Dict[str, int]) -> str:
    lines = text.splitlines(keepends=True)
    out_lines: List[str] = []

    pat_orisha_nla = re.compile(r"\b(?:Orisha|Oricha)[\s\-]+nla\b", re.IGNORECASE)
    pat_orunmila = re.compile(r"\bOrun[\s\-]?mill?a(?:\u0301|́)?\b", re.IGNORECASE)
    pat_ifa = re.compile(r"\bifa\b", re.IGNORECASE)
    pat_orisha = re.compile(r"\b(?:Oricha(?:s|́s)?|Orisa(?:s)?)\b", re.IGNORECASE)
    pat_eshu_elegba_compound = re.compile(r"\bEshu[\s\-]+Elegba\b", re.IGNORECASE)
    pat_eshu_alias = re.compile(r"\b(?:Eleggua|Eleguá|Elegba|Echu|Eshú)\b", re.IGNORECASE)
    pat_odu = re.compile(r"\bodu\b", re.IGNORECASE)
    pat_orun = re.compile(r"\borun\b", re.IGNORECASE)

    repl_odu = case_preserving_replace("odu", "odù", "Odù", "ODÙ")
    repl_orun = case_preserving_replace("orun", "orún", "Orún", "ORÚN")

    for line in lines:
        # Preserve section-heading lines exactly unchanged.
        core = line[:-1] if line.endswith("\n") else line
        if is_heading_line(core):
            out_lines.append(line)
            continue

        working = line

        working, n = pat_orisha_nla.subn("Orisha-Nlá", working)
        counts["orisha_nla"] += n

        working, n = pat_orunmila.subn("Orúnmila", working)
        counts["orunmila"] += n

        working, n = pat_ifa.subn("Ifá", working)
        counts["ifa"] += n

        working, n = pat_orisha.subn(normalize_orisha_variant, working)
        counts["orisha"] += n

        working, n = pat_eshu_elegba_compound.subn("Eshu-Elegba", working)
        counts["eshu_elegba_compound"] += n

        working, n = pat_eshu_alias.subn("Eshu-Elegba", working)
        counts["eshu_elegba_alias"] += n

        working, n = pat_odu.subn(repl_odu, working)
        counts["accent_odu"] += n

        working, n = pat_orun.subn(repl_orun, working)
        counts["accent_orun"] += n

        out_lines.append(working)

    return "".join(out_lines)


def main() -> None:
    if not INPUT_JSON.exists():
        raise SystemExit(f"Missing input: {INPUT_JSON}")

    data = json.loads(INPUT_JSON.read_text(encoding="utf-8"))
    odu_map = data.get("odu")
    if not isinstance(odu_map, dict):
        raise SystemExit("Invalid schema: expected top-level 'odu' map")

    counts = {
        "ifa": 0,
        "orunmila": 0,
        "orisha": 0,
        "orisha_nla": 0,
        "eshu_elegba_compound": 0,
        "eshu_elegba_alias": 0,
        "accent_odu": 0,
        "accent_orun": 0,
    }

    affected_odus: List[str] = []
    changed_fields: List[Tuple[str, str, int, int, str, str]] = []

    for odu_key, odu_entry in odu_map.items():
        if not isinstance(odu_entry, dict):
            continue
        content = odu_entry.get("content")
        if not isinstance(content, dict):
            continue

        entry_changed = False

        for field_key, field_value in list(content.items()):
            if field_key == "name":
                continue
            if not isinstance(field_value, str):
                continue

            before = field_value
            after = normalize_text(before, counts)
            if before != after:
                content[field_key] = after
                entry_changed = True
                changed_fields.append(
                    (
                        str(odu_key),
                        str(field_key),
                        len(before),
                        len(after),
                        before[:240].replace("\n", "\\n"),
                        after[:240].replace("\n", "\\n"),
                    )
                )

        if entry_changed:
            affected_odus.append(str(odu_key))

    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # Publish to patched asset only (assets/odu_content.json remains untouched).
    shutil.copy2(OUTPUT_JSON, PUBLISH_JSON)

    normalized_tokens = [
        "Ifá",
        "Orúnmila",
        "Orisha",
        "Orisha-Nlá",
        "Eshu-Elegba",
        "Odù",
        "Orún",
    ]

    total_replacements = sum(counts.values())
    report_lines = [
        "# Odù Normalization Report",
        "",
        f"- Generated UTC: `{dt.datetime.utcnow().replace(microsecond=0).isoformat()}Z`",
        f"- Input: `{INPUT_JSON}`",
        f"- Output (build): `{OUTPUT_JSON}`",
        f"- Published to patched asset: `{PUBLISH_JSON}`",
        "- `assets/odu_content.json` modified: `false`",
        "",
        "## Replacement Totals",
        "",
        f"- ifa -> Ifá: **{counts['ifa']}**",
        f"- Orunmila* -> Orúnmila: **{counts['orunmila']}**",
        f"- Oricha/Orisa* -> Orisha*: **{counts['orisha']}**",
        f"- Orisha nla/Oricha nla -> Orisha-Nlá: **{counts['orisha_nla']}**",
        f"- Eshu Elegba -> Eshu-Elegba: **{counts['eshu_elegba_compound']}**",
        f"- Eleggua/Eleguá/Elegba/Echu/Eshú -> Eshu-Elegba: **{counts['eshu_elegba_alias']}**",
        f"- Odu -> Odù: **{counts['accent_odu']}**",
        f"- Orun -> Orún: **{counts['accent_orun']}**",
        f"- Total replacements: **{total_replacements}**",
        "",
        "## Normalized Tokens",
        "",
    ]
    report_lines.extend([f"- {tok}" for tok in normalized_tokens])
    report_lines.extend([
        "",
        f"## Odù Entries Affected ({len(affected_odus)})",
        "",
    ])
    if affected_odus:
        report_lines.extend([f"- {k}" for k in sorted(affected_odus)])
    else:
        report_lines.append("- None")

    REPORT_MD.write_text("\n".join(report_lines).rstrip() + "\n", encoding="utf-8")

    diff_lines = [
        "# Odù Normalization Diff",
        "",
        f"- Changed fields: **{len(changed_fields)}**",
        "",
    ]
    for odu_key, field_key, b_len, a_len, b_prev, a_prev in changed_fields:
        diff_lines.extend(
            [
                f"## {odu_key} / {field_key}",
                "",
                f"- Length: `{b_len} -> {a_len}`",
                "- Before preview:",
                "```text",
                b_prev,
                "```",
                "- After preview:",
                "```text",
                a_prev,
                "```",
                "",
            ]
        )

    DIFF_MD.write_text("\n".join(diff_lines).rstrip() + "\n", encoding="utf-8")

    print(f"Normalization complete. Total replacements: {total_replacements}")
    print(f"Affected odù entries: {len(affected_odus)}")
    print(f"Wrote: {OUTPUT_JSON}")
    print(f"Wrote: {REPORT_MD}")
    print(f"Wrote: {DIFF_MD}")
    print(f"Published: {PUBLISH_JSON}")


if __name__ == "__main__":
    main()
