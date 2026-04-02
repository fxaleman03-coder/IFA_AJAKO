#!/usr/bin/env python3
"""Fix Baba Ejiogbe section structure with strict heading-based parsing.

Updates only assets/odu_content_patched.json (target key: BABA OGBE)
from the specified DOCX source, preserving assets/odu_content.json untouched.
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import json
import re
import shutil
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
ASSET_PATCHED = ROOT / "assets" / "odu_content_patched.json"
BUILD_PATCHED = ROOT / "build" / "odu_content_patched.json"
REPORT_MD = ROOT / "build" / "baba_ejiogbe_structure_fix_report.md"
DIFF_MD = ROOT / "build" / "baba_ejiogbe_structure_diff.md"
SUMMARY_JSON = ROOT / "build" / "baba_ejiogbe_structure_summary.json"

TARGET_KEY = "BABA OGBE"

SECTION_ORDER = [
    "REZO",
    "SUYERE",
    "NACE",
    "DESCRIPCION",
    "OBRAS",
    "DICE_IFA",
    "EWES",
    "REFRANES",
    "ESHU",
    "HISTORIAS",
]

SECTION_TO_FIELDS = {
    "REZO": ["rezoYoruba"],
    "SUYERE": ["suyereYoruba"],
    "NACE": ["nace"],
    "DESCRIPCION": ["descripcion", "description"],
    "OBRAS": ["obrasYEbbo", "obras"],
    "DICE_IFA": ["diceIfa"],
    "EWES": ["ewes", "ewesYoruba"],
    "REFRANES": ["refranes"],
    "ESHU": ["eshu"],
    "HISTORIAS": ["historiasYPatakies", "historiasPatakies", "historias"],
}


@dataclass(frozen=True)
class HeadingRule:
    section: str
    pattern: re.Pattern[str]


def compile_rules() -> Dict[str, HeadingRule]:
    rules = {
        "REZO": HeadingRule(
            "REZO", re.compile(r"^\s*REZO\b\s*[:\-–—]?\s*", re.IGNORECASE)
        ),
        "SUYERE": HeadingRule(
            "SUYERE", re.compile(r"^\s*SUYERE\b\s*[:\-–—]?\s*", re.IGNORECASE)
        ),
        "NACE": HeadingRule(
            "NACE",
            re.compile(
                r"^\s*EN\s+ESTE\s+OD(?:U|O|Ù)\s+NACE\b\s*[:\-–—]?\s*",
                re.IGNORECASE,
            ),
        ),
        "DESCRIPCION": HeadingRule(
            "DESCRIPCION",
            re.compile(
                r"^\s*DESCRIPCI(?:Ó|O)N\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*",
                re.IGNORECASE,
            ),
        ),
        "OBRAS": HeadingRule(
            "OBRAS",
            re.compile(
                r"^\s*OBRAS\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*", re.IGNORECASE
            ),
        ),
        "DICE_IFA": HeadingRule(
            "DICE_IFA",
            re.compile(r"^\s*DICE\s+IF(?:Á|A)\b\s*[:\.-]?\s*", re.IGNORECASE),
        ),
        "EWES": HeadingRule(
            "EWES",
            re.compile(
                r"^\s*EWES\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*", re.IGNORECASE
            ),
        ),
        "REFRANES": HeadingRule(
            "REFRANES",
            re.compile(
                r"^\s*REFRANES\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*",
                re.IGNORECASE,
            ),
        ),
        "ESHU": HeadingRule(
            "ESHU",
            re.compile(
                r"^\s*ESHU[\s\-–—]*ELEGBA\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*",
                re.IGNORECASE,
            ),
        ),
        "HISTORIAS": HeadingRule(
            "HISTORIAS",
            re.compile(
                r"^\s*HISTORIAS?\s+O\s+PATAK(?:I|Í)N(?:E|É)?S\s+DEL\s+OD(?:U|O|Ù)\b\s*[:\-–—]?\s*",
                re.IGNORECASE,
            ),
        ),
    }
    return rules


def load_docx_paragraphs(docx_path: Path) -> List[str]:
    with zipfile.ZipFile(docx_path) as zf:
        xml = zf.read("word/document.xml")
    root = ET.fromstring(xml)
    ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
    out: List[str] = []
    for p in root.findall(".//w:p", ns):
        txt = "".join((t.text or "") for t in p.findall(".//w:t", ns))
        out.append(txt.replace("\u00A0", " ").rstrip())
    return out


def normalize_block(lines: List[str]) -> str:
    out = list(lines)
    while out and not out[0].strip():
        out.pop(0)
    while out and not out[-1].strip():
        out.pop()
    return "\n".join(out).rstrip()


def find_first_index(lines: List[str], pattern: re.Pattern[str], start: int) -> Optional[int]:
    for i in range(start, len(lines)):
        if pattern.match(lines[i] or ""):
            return i
    return None


def find_section_starts(lines: List[str], rules: Dict[str, HeadingRule]) -> Dict[str, int]:
    starts: Dict[str, int] = {}
    cursor = 0
    for section in SECTION_ORDER:
        idx = find_first_index(lines, rules[section].pattern, cursor)
        if idx is None:
            continue
        starts[section] = idx
        cursor = idx + 1
    return starts


def split_ranges(starts: Dict[str, int], total: int) -> Dict[str, Tuple[int, int]]:
    ranges: Dict[str, Tuple[int, int]] = {}
    present = [s for s in SECTION_ORDER if s in starts]
    for i, section in enumerate(present):
        start = starts[section]
        if i + 1 < len(present):
            end = starts[present[i + 1]]
        else:
            end = total
        ranges[section] = (start, end)
    return ranges


def extract_label_blocks(lines: List[str], label_pattern: re.Pattern[str]) -> str:
    blocks: List[str] = []
    current: List[str] = []

    def flush() -> None:
        nonlocal current
        block = normalize_block(current)
        if block:
            blocks.append(block)
        current = []

    for line in lines:
        m = label_pattern.match(line or "")
        if m:
            flush()
            remainder = (line[m.end() :] or "").strip()
            if remainder:
                current.append(remainder)
            continue
        if current or blocks or any((x or "").strip() for x in lines):
            current.append(line)

    flush()
    return "\n\n".join(blocks).rstrip()


def extract_standard_section(
    lines: List[str],
    heading_pattern: re.Pattern[str],
    *,
    keep_heading_line: bool,
) -> str:
    if not lines:
        return ""
    first = lines[0]
    m = heading_pattern.match(first or "")
    body: List[str] = []
    if m:
        if keep_heading_line:
            body.append(first.rstrip())
        else:
            remainder = (first[m.end() :] or "").strip()
            if remainder:
                body.append(remainder)
        body.extend((ln or "").rstrip() for ln in lines[1:])
    else:
        body.extend((ln or "").rstrip() for ln in lines)
    return normalize_block(body)


def parse_sections(lines: List[str], rules: Dict[str, HeadingRule]) -> Dict[str, str]:
    starts = find_section_starts(lines, rules)
    ranges = split_ranges(starts, len(lines))

    sections = {k: "" for k in SECTION_ORDER}

    if "REZO" in ranges:
        s, e = ranges["REZO"]
        sections["REZO"] = extract_label_blocks(lines[s:e], rules["REZO"].pattern)

    if "SUYERE" in ranges:
        s, e = ranges["SUYERE"]
        sections["SUYERE"] = extract_label_blocks(lines[s:e], rules["SUYERE"].pattern)

    for section in ["NACE", "DESCRIPCION", "OBRAS", "DICE_IFA", "EWES", "REFRANES", "ESHU", "HISTORIAS"]:
        if section not in ranges:
            continue
        s, e = ranges[section]
        keep_heading = section == "DESCRIPCION"
        sections[section] = extract_standard_section(
            lines[s:e], rules[section].pattern, keep_heading_line=keep_heading
        )

    return sections


def choose_field(content: Dict[str, object], section: str) -> str:
    for key in SECTION_TO_FIELDS[section]:
        if key in content:
            return key
    return SECTION_TO_FIELDS[section][0]


def truncate_lines(text: str, max_lines: int = 60) -> str:
    lines = text.splitlines()
    if len(lines) <= max_lines:
        return text
    return "\n".join(lines[:max_lines]) + f"\n... [truncated {len(lines)-max_lines} lines]"


def contains_story_marker(text: str) -> bool:
    up = text.upper()
    return any(tok in up for tok in ["HISTORIA", "PATAKIN", "PATAKINES"])


def main() -> None:
    parser = argparse.ArgumentParser(description="Fix Baba Ejiogbe strict structure from DOCX")
    parser.add_argument(
        "--docx",
        default="/Users/fxaleman03gmail.com/Documents/NEW ODU/1- EJIOGBE.docx",
        help="Source DOCX path",
    )
    args = parser.parse_args()

    docx_path = Path(args.docx).expanduser().resolve()
    if not docx_path.exists():
        raise SystemExit(f"DOCX not found: {docx_path}")
    if not ASSET_PATCHED.exists():
        raise SystemExit(f"Missing source JSON: {ASSET_PATCHED}")

    data = json.loads(ASSET_PATCHED.read_text(encoding="utf-8"))
    odu_map = data.get("odu")
    if not isinstance(odu_map, dict):
        raise SystemExit("Invalid schema: missing odu map")
    if TARGET_KEY not in odu_map or not isinstance(odu_map[TARGET_KEY], dict):
        raise SystemExit(f"Target key missing: {TARGET_KEY}")

    target = odu_map[TARGET_KEY]
    content = target.get("content")
    if not isinstance(content, dict):
        raise SystemExit("Invalid target content object")

    before_data = copy.deepcopy(data)
    before_content = copy.deepcopy(content)

    rules = compile_rules()
    paragraphs = load_docx_paragraphs(docx_path)
    sections = parse_sections(paragraphs, rules)

    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = ASSET_PATCHED.with_name(
        f"{ASSET_PATCHED.name}.bak_baba_ejiogbe_fix_{timestamp}"
    )
    shutil.copy2(ASSET_PATCHED, backup_path)

    section_summary: Dict[str, Dict[str, object]] = {}
    changed_sections = 0
    missing_sections = 0

    for section in SECTION_ORDER:
        field = choose_field(content, section)
        before = str(before_content.get(field, "") or "")
        incoming = str(sections.get(section, "") or "")
        missing = not incoming.strip()

        if not missing:
            content[field] = incoming
            after = incoming
        else:
            after = before
            missing_sections += 1

        changed = before != after
        if changed:
            changed_sections += 1

        section_summary[section] = {
            "json_field": field,
            "changed": changed,
            "missing_in_docx": missing,
            "before_len": len(before),
            "after_len": len(after),
            "before_preview": before[:240],
            "after_preview": after[:240],
        }

    # Safety: only one Odù changed.
    changed_keys = []
    for key in odu_map.keys():
        if before_data["odu"].get(key) != data["odu"].get(key):
            changed_keys.append(key)
    if changed_keys not in ([TARGET_KEY], []):
        raise SystemExit(
            f"Safety check failed: only {TARGET_KEY} may change, got {changed_keys}"
        )

    BUILD_PATCHED.parent.mkdir(parents=True, exist_ok=True)
    BUILD_PATCHED.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    shutil.copy2(BUILD_PATCHED, ASSET_PATCHED)

    rezo_field = choose_field(content, "REZO")
    suyere_field = choose_field(content, "SUYERE")
    historias_field = choose_field(content, "HISTORIAS")
    descripcion_field = choose_field(content, "DESCRIPCION")

    rezo = str(content.get(rezo_field, "") or "")
    suyere = str(content.get(suyere_field, "") or "")
    historias = str(content.get(historias_field, "") or "")
    descripcion = str(content.get(descripcion_field, "") or "")

    validation = {
        "rezo_has_main_baba_ejiogbe": rezo.lstrip().upper().startswith("BABA EJIOGBE"),
        "rezo_no_ebo_tokens": re.search(r"\bEB[ÓO]\b", rezo, flags=re.IGNORECASE) is None,
        "rezo_no_story_markers": not contains_story_marker(rezo),
        "historias_has_story_markers": contains_story_marker(historias),
        "suyere_no_descripcion_tokens": (
            "DESCRIPCI" not in suyere.upper() and "ESTE ES EL ODU" not in suyere.upper()
        ),
        "descripcion_starts_heading": descripcion.lstrip().upper().startswith("DESCRIPCIÓN DEL ODU")
        or descripcion.lstrip().upper().startswith("DESCRIPCION DEL ODU"),
    }

    summary = {
        "timestamp": timestamp,
        "source_docx": str(docx_path),
        "target_odu_key": TARGET_KEY,
        "target_content_name": str(content.get("name", "")),
        "backup_path": str(backup_path),
        "assets_odu_content_json_modified": False,
        "changed_odu_keys_count": len(changed_keys),
        "changed_odu_keys": changed_keys,
        "counts": {
            "total_sections": len(SECTION_ORDER),
            "changed_sections": changed_sections,
            "missing_sections_in_docx": missing_sections,
        },
        "validation": validation,
        "sections": section_summary,
        "outputs": {
            "build_patched_json": str(BUILD_PATCHED),
            "assets_patched_json": str(ASSET_PATCHED),
            "report_md": str(REPORT_MD),
            "diff_md": str(DIFF_MD),
            "summary_json": str(SUMMARY_JSON),
        },
    }
    SUMMARY_JSON.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    diff_lines: List[str] = [
        "# Baba Ejiogbe Structure Fix Diff",
        "",
        f"- Source DOCX: `{docx_path}`",
        f"- Target Odù key: `{TARGET_KEY}`",
        "",
    ]

    for section in SECTION_ORDER:
        info = section_summary[section]
        field = str(info["json_field"])
        before = str(before_content.get(field, "") or "")
        after = str(content.get(field, "") or "")

        diff_lines.extend(
            [
                f"## {section} -> `{field}`",
                "",
                f"- Changed: `{str(info['changed']).lower()}`",
                f"- Missing in DOCX: `{str(info['missing_in_docx']).lower()}`",
                f"- Lengths: `{len(before)} -> {len(after)}`",
                "",
                "### BEFORE (first 60 lines)",
                "```text",
                truncate_lines(before, 60),
                "```",
                "",
                "### AFTER (first 60 lines)",
                "```text",
                truncate_lines(after, 60),
                "```",
                "",
            ]
        )

    DIFF_MD.write_text("\n".join(diff_lines).rstrip() + "\n", encoding="utf-8")

    report_lines: List[str] = [
        "# Baba Ejiogbe Structure Fix Report",
        "",
        f"- Source DOCX: `{docx_path}`",
        f"- Target Odù key: `{TARGET_KEY}`",
        f"- Target content.name: `{content.get('name','')}`",
        f"- Backup created: `{backup_path}`",
        "- assets/odu_content.json NOT modified: `true`",
        f"- Changed Odù keys: `{len(changed_keys)}` -> `{changed_keys}`",
        "",
        "## Validation",
        "",
        f"- rezoYoruba starts with `BABA EJIOGBE`: `{str(validation['rezo_has_main_baba_ejiogbe']).lower()}`",
        f"- rezoYoruba has no Ebó tokens: `{str(validation['rezo_no_ebo_tokens']).lower()}`",
        f"- rezoYoruba has no story markers: `{str(validation['rezo_no_story_markers']).lower()}`",
        f"- historiasYPatakies has story markers: `{str(validation['historias_has_story_markers']).lower()}`",
        f"- suyereYoruba has no descripción prose markers: `{str(validation['suyere_no_descripcion_tokens']).lower()}`",
        f"- descripcion starts with heading: `{str(validation['descripcion_starts_heading']).lower()}`",
        "",
        "## Section Summary",
        "",
        "| Section | JSON Field | Changed | Missing in DOCX | Before Len | After Len |",
        "|---|---|---|---|---:|---:|",
    ]

    for section in SECTION_ORDER:
        info = section_summary[section]
        report_lines.append(
            f"| {section} | `{info['json_field']}` | {'yes' if info['changed'] else 'no'} | {'yes' if info['missing_in_docx'] else 'no'} | {info['before_len']} | {info['after_len']} |"
        )

    report_lines.extend([
        "",
        "## Key Before/After Previews (first 120 chars)",
        "",
    ])

    for sec in ["REZO", "SUYERE", "DESCRIPCION", "OBRAS", "HISTORIAS"]:
        field = section_summary[sec]["json_field"]
        before = str(before_content.get(field, "") or "")
        after = str(content.get(field, "") or "")
        report_lines.append(f"- {sec}/{field} before120: `{before[:120]}`")
        report_lines.append(f"- {sec}/{field} after120: `{after[:120]}`")
        report_lines.append("")

    REPORT_MD.write_text("\n".join(report_lines).rstrip() + "\n", encoding="utf-8")

    print("Baba Ejiogbe structure fix completed.")
    print(f"Source DOCX: {docx_path}")
    print(f"Target key: {TARGET_KEY}")
    print(f"Changed sections: {changed_sections}/{len(SECTION_ORDER)}")
    print(f"Missing DOCX sections left unchanged: {missing_sections}")
    print(f"Backup: {backup_path}")
    print(f"Report: {REPORT_MD}")
    print(f"Diff:   {DIFF_MD}")
    print(f"Summary:{SUMMARY_JSON}")
    print("assets/odu_content.json NOT modified.")


if __name__ == "__main__":
    main()
