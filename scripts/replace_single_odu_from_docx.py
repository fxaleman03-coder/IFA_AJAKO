#!/usr/bin/env python3
"""Re-import Baba Ejiogbe sections from DOCX into assets/odu_content_patched.json.

Safety guarantees:
- Never modifies assets/odu_content.json
- Updates only one Odù entry (BABA OGBE proven target)
- Creates a timestamped backup before writing
- Writes build/odu_content_patched.json first, then publishes to assets
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import json
import re
import shutil
import unicodedata
import zipfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
ASSET_PATCHED = ROOT / "assets" / "odu_content_patched.json"
BUILD_PATCHED = ROOT / "build" / "odu_content_patched.json"
REPORT_MD = ROOT / "build" / "baba_ejiogbe_reimport_report.md"
DIFF_MD = ROOT / "build" / "baba_ejiogbe_reimport_diff.md"
SUMMARY_JSON = ROOT / "build" / "baba_ejiogbe_reimport_summary.json"
PREV_SUMMARY_JSON = ROOT / "build" / "baba_ejiogbe_docx_import_summary.json"

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
    "SUYERE": ["suyereYoruba", "suyereEspanol"],
    "NACE": ["nace"],
    "DESCRIPCION": ["descripcion", "description"],
    "OBRAS": ["obras", "obrasYEbbo"],
    "DICE_IFA": ["diceIfa"],
    "EWES": ["ewes", "ewesYoruba"],
    "REFRANES": ["refranes"],
    "ESHU": ["eshu"],
    "HISTORIAS": ["historiasYPatakies", "historiasPatakies", "historias"],
}


def fold(text: str) -> str:
    text = unicodedata.normalize("NFD", text)
    text = "".join(ch for ch in text if unicodedata.category(ch) != "Mn")
    text = text.upper()
    text = text.replace("_", " ").replace("-", " ")
    text = re.sub(r"[^\w\s:]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def resolve_default_docx() -> Path:
    # Prefer exact source used by previous import if available.
    if PREV_SUMMARY_JSON.exists():
        try:
            payload = json.loads(PREV_SUMMARY_JSON.read_text(encoding="utf-8"))
            source = str(payload.get("source_docx", "")).strip()
            if source:
                p = Path(source).expanduser()
                if p.exists():
                    return p.resolve()
        except Exception:
            pass

    fallback = ROOT / "sources" / "1- EJIOGBE.docx"
    return fallback.resolve()


def load_docx_paragraphs(docx_path: Path) -> List[str]:
    try:
        from docx import Document  # type: ignore

        doc = Document(str(docx_path))
        return [p.text.replace("\u00A0", " ").rstrip() for p in doc.paragraphs]
    except Exception:
        with zipfile.ZipFile(docx_path) as zf:
            xml = zf.read("word/document.xml")
        root = ET.fromstring(xml)
        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
        paragraphs: List[str] = []
        for p in root.findall(".//w:p", ns):
            chunks: List[str] = []
            for t in p.findall(".//w:t", ns):
                chunks.append(t.text or "")
            paragraphs.append("".join(chunks).replace("\u00A0", " ").rstrip())
        return paragraphs


def match_rezo_label(raw_line: str) -> Optional[str]:
    m = re.match(r"^\s*REZO\s*:\s*(.*)$", raw_line, flags=re.IGNORECASE)
    if not m:
        return None
    return (m.group(1) or "").rstrip()


def match_suyere_label(raw_line: str) -> Optional[str]:
    m = re.match(r"^\s*SUYERE\s*:\s*(.*)$", raw_line, flags=re.IGNORECASE)
    if not m:
        return None
    return (m.group(1) or "").rstrip()


def detect_major_heading(raw_line: str) -> Optional[str]:
    if not raw_line.strip():
        return None
    line = fold(raw_line)

    checks: List[Tuple[str, List[str]]] = [
        ("NACE", [r"^EN ESTE ODU NACE\b", r"^EN ESTE ODO NACE\b", r"^EN ESTE ODU NACE\b"]),
        (
            "DESCRIPCION",
            [
                r"^DESCRIPCION DEL ODU BABA EJIOGBE\b",
                r"^DESCRIPCION DEL ODO BABA EJIOGBE\b",
            ],
        ),
        ("OBRAS", [r"^OBRAS DEL ODU\b", r"^OBRAS DEL ODO\b"]),
        ("DICE_IFA", [r"^DICE IFA\b"]),
        ("EWES", [r"^EWES DEL ODU\b", r"^EWES DEL ODO\b"]),
        ("REFRANES", [r"^REFRANES DEL ODU\b", r"^REFRANES DEL ODO\b"]),
        ("ESHU", [r"^ESHU ELEGBA DEL ODU\b", r"^ESHU ELEGBA DEL ODO\b"]),
        (
            "HISTORIAS",
            [
                r"^HISTORIAS O PATAKINES DEL ODU\b",
                r"^HISTORIAS O PATAKINES DEL ODO\b",
            ],
        ),
    ]

    for section, patterns in checks:
        for pattern in patterns:
            if re.search(pattern, line, flags=re.IGNORECASE):
                return section
    return None


def normalize_block_lines(lines: List[str]) -> str:
    out = list(lines)
    while out and not out[0].strip():
        out.pop(0)
    while out and not out[-1].strip():
        out.pop()
    return "\n".join(out).rstrip()


def extract_rezo_suyere_blocks(paragraphs: List[str]) -> Dict[str, str]:
    rezo_blocks: List[str] = []
    suyere_blocks: List[str] = []

    i = 0
    while i < len(paragraphs):
        line = paragraphs[i]
        rezo_inline = match_rezo_label(line)
        suyere_inline = match_suyere_label(line)

        if rezo_inline is None and suyere_inline is None:
            i += 1
            continue

        is_rezo = rezo_inline is not None
        inline = rezo_inline if is_rezo else suyere_inline
        block_lines: List[str] = []
        if inline and inline.strip():
            block_lines.append(inline.strip())

        j = i + 1
        while j < len(paragraphs):
            next_line = paragraphs[j]
            if (
                detect_major_heading(next_line) is not None
                or match_rezo_label(next_line) is not None
                or match_suyere_label(next_line) is not None
            ):
                break
            block_lines.append(next_line.rstrip())
            j += 1

        block = normalize_block_lines(block_lines)
        if block:
            if is_rezo:
                rezo_blocks.append(block)
            else:
                suyere_blocks.append(block)

        i = j

    return {
        "REZO": "\n\n".join(rezo_blocks).rstrip(),
        "SUYERE": "\n\n".join(suyere_blocks).rstrip(),
    }


def extract_major_sections(paragraphs: List[str]) -> Dict[str, str]:
    buckets: Dict[str, List[str]] = {
        "NACE": [],
        "DESCRIPCION": [],
        "OBRAS": [],
        "DICE_IFA": [],
        "EWES": [],
        "REFRANES": [],
        "ESHU": [],
        "HISTORIAS": [],
    }

    i = 0
    while i < len(paragraphs):
        raw_heading_line = paragraphs[i]
        heading = detect_major_heading(raw_heading_line)
        if heading is None:
            i += 1
            continue

        j = i + 1
        block_lines: List[str] = []
        if heading == "DESCRIPCION":
            # Requirement: descripcion must begin exactly at this heading line.
            block_lines.append(raw_heading_line.rstrip())
        while j < len(paragraphs):
            if detect_major_heading(paragraphs[j]) is not None:
                break
            block_lines.append(paragraphs[j].rstrip())
            j += 1

        block = normalize_block_lines(block_lines)
        if block:
            buckets[heading].append(block)

        i = j

    out: Dict[str, str] = {}
    for section, blocks in buckets.items():
        out[section] = "\n\n".join(blocks).rstrip()
    return out


def extract_sections(paragraphs: List[str]) -> Dict[str, str]:
    sections = {k: "" for k in SECTION_ORDER}
    sections.update(extract_rezo_suyere_blocks(paragraphs))
    sections.update(extract_major_sections(paragraphs))
    return sections


def choose_field(content: Dict[str, object], section_name: str) -> str:
    candidates = SECTION_TO_FIELDS[section_name]
    for candidate in candidates:
        if candidate in content:
            return candidate
    return candidates[0]


def truncate_lines(text: str, max_lines: int = 60) -> str:
    lines = text.splitlines()
    if len(lines) <= max_lines:
        return text
    return "\n".join(lines[:max_lines]) + f"\n... [truncated {len(lines) - max_lines} lines]"


def main() -> None:
    parser = argparse.ArgumentParser(description="Re-import Baba Ejiogbe from DOCX.")
    parser.add_argument(
        "--docx",
        default=str(resolve_default_docx()),
        help="Path to source DOCX (defaults to exact previous import source if available).",
    )
    args = parser.parse_args()

    docx_path = Path(args.docx).expanduser().resolve()
    if not docx_path.exists():
        raise SystemExit(f"DOCX not found: {docx_path}")
    if not ASSET_PATCHED.exists():
        raise SystemExit(f"Missing patched source JSON: {ASSET_PATCHED}")

    BUILD_PATCHED.parent.mkdir(parents=True, exist_ok=True)

    data = json.loads(ASSET_PATCHED.read_text(encoding="utf-8"))
    odu_map = data.get("odu")
    if not isinstance(odu_map, dict):
        raise SystemExit("Unsupported JSON schema: top-level 'odu' must be an object map.")

    if "BABA OGBE" not in odu_map or not isinstance(odu_map["BABA OGBE"], dict):
        raise SystemExit("Target key 'BABA OGBE' not found in patched JSON.")

    target_key = "BABA OGBE"
    target_entry = odu_map[target_key]
    content = target_entry.get("content")
    if not isinstance(content, dict):
        raise SystemExit("Target content object is missing.")

    before_data = copy.deepcopy(data)
    before_content = copy.deepcopy(content)

    paragraphs = load_docx_paragraphs(docx_path)
    sections = extract_sections(paragraphs)

    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = ASSET_PATCHED.with_name(
        f"{ASSET_PATCHED.name}.bak_baba_ejiogbe_reimport_{timestamp}"
    )
    shutil.copy2(ASSET_PATCHED, backup_path)

    summary_sections: Dict[str, Dict[str, object]] = {}
    changed_count = 0
    missing_count = 0

    for section_name in SECTION_ORDER:
        field_name = choose_field(content, section_name)
        before = str(before_content.get(field_name, "") or "")
        incoming = sections.get(section_name, "")
        missing_in_docx = not bool(incoming.strip())

        if missing_in_docx:
            after = before
            missing_count += 1
        else:
            after = incoming
            content[field_name] = incoming

        changed = before != after
        if changed:
            changed_count += 1

        summary_sections[section_name] = {
            "json_field": field_name,
            "missing_in_docx": missing_in_docx,
            "changed": changed,
            "before_len": len(before),
            "after_len": len(after),
            "before_preview": before[:240],
            "after_preview": after[:240],
        }

    # Write updated JSON to build then publish to assets.
    BUILD_PATCHED.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    shutil.copy2(BUILD_PATCHED, ASSET_PATCHED)

    changed_odu_keys = []
    for key in odu_map.keys():
        if before_data["odu"].get(key) != data["odu"].get(key):
            changed_odu_keys.append(key)

    allowed_changed_sets = ([], [target_key])
    if changed_odu_keys not in allowed_changed_sets:
        raise SystemExit(
            f"Safety check failed: expected only [{target_key}] changed (or no-op), got {changed_odu_keys}"
        )

    rezo_value = str(content.get(choose_field(content, "REZO"), "") or "")
    suyere_value = str(content.get(choose_field(content, "SUYERE"), "") or "")
    descripcion_value = str(content.get(choose_field(content, "DESCRIPCION"), "") or "")

    validation = {
        "rezo_has_main": "BABA EJIOGBE ALALEKUN" in rezo_value.upper(),
        "rezo_has_second": "ORUNMILA NI ODI ELESE MESE" in rezo_value.upper(),
        "suyere_starts_ashinima": suyere_value.lstrip().upper().startswith("ASHINIMA ASHINIMA"),
        "descripcion_starts_heading": fold(descripcion_value.lstrip()).startswith(
            "DESCRIPCION DEL ODU BABA EJIOGBE"
        ),
        "descripcion_not_in_suyere": (
            "DESCRIPCION DEL ODU BABA EJIOGBE" not in fold(suyere_value)
            and "DESCRIPCIÓN DEL ODU BABA EJIOGBE" not in suyere_value.upper()
        ),
    }

    # Diff report.
    diff_lines: List[str] = []
    diff_lines.append("# Baba Ejiogbe Reimport Diff")
    diff_lines.append("")
    diff_lines.append(f"- Source DOCX: `{docx_path}`")
    diff_lines.append(f"- Target Odù key: `{target_key}`")
    diff_lines.append("")
    for section_name in SECTION_ORDER:
        info = summary_sections[section_name]
        field_name = info["json_field"]
        before = str(before_content.get(field_name, "") or "")
        after = str(content.get(field_name, "") or "")
        diff_lines.append(f"## {section_name} -> `{field_name}`")
        diff_lines.append("")
        diff_lines.append(f"- Changed: `{str(info['changed']).lower()}`")
        diff_lines.append(f"- Missing in DOCX: `{str(info['missing_in_docx']).lower()}`")
        diff_lines.append(f"- Lengths: `{len(before)} -> {len(after)}`")
        diff_lines.append("")
        diff_lines.append("### BEFORE (first 60 lines)")
        diff_lines.append("```text")
        diff_lines.append(truncate_lines(before, 60))
        diff_lines.append("```")
        diff_lines.append("")
        diff_lines.append("### AFTER (first 60 lines)")
        diff_lines.append("```text")
        diff_lines.append(truncate_lines(after, 60))
        diff_lines.append("```")
        diff_lines.append("")
    DIFF_MD.write_text("\n".join(diff_lines).rstrip() + "\n", encoding="utf-8")

    total_sections = len(SECTION_ORDER)
    unchanged_count = total_sections - changed_count

    summary_payload = {
        "timestamp": timestamp,
        "source_docx": str(docx_path),
        "target_odu_key": target_key,
        "target_content_name": str(content.get("name", "")),
        "backup_path": str(backup_path),
        "assets_odu_content_json_modified": False,
        "changed_odu_keys_count": len(changed_odu_keys),
        "changed_odu_keys": changed_odu_keys,
        "counts": {
            "total_sections": total_sections,
            "changed_sections": changed_count,
            "unchanged_sections": unchanged_count,
            "missing_sections_in_docx": missing_count,
        },
        "validation": validation,
        "sections": summary_sections,
        "outputs": {
            "build_patched_json": str(BUILD_PATCHED),
            "assets_patched_json": str(ASSET_PATCHED),
            "report_md": str(REPORT_MD),
            "diff_md": str(DIFF_MD),
            "summary_json": str(SUMMARY_JSON),
        },
    }
    SUMMARY_JSON.write_text(
        json.dumps(summary_payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    report_lines = [
        "# Baba Ejiogbe Reimport Report",
        "",
        f"- Source DOCX: `{docx_path}`",
        f"- Target Odù key: `{target_key}`",
        f"- Target content.name: `{content.get('name', '')}`",
        f"- Backup created: `{backup_path}`",
        "- assets/odu_content.json NOT modified: `true`",
        f"- Changed Odù keys: `{len(changed_odu_keys)}` -> `{changed_odu_keys}`",
        "",
        "## Validation",
        "",
        f"- rezoYoruba has main `BABA EJIOGBE ALALEKUN...`: `{str(validation['rezo_has_main']).lower()}`",
        f"- rezoYoruba has second `ORUNMILA NI ODI ELESE MESE...`: `{str(validation['rezo_has_second']).lower()}`",
        f"- suyereYoruba starts `ASHINIMA ASHINIMA...`: `{str(validation['suyere_starts_ashinima']).lower()}`",
        f"- descripcion starts `DESCRIPCIÓN DEL ODU BABA EJIOGBE`: `{str(validation['descripcion_starts_heading']).lower()}`",
        f"- descripcion heading not inside suyereYoruba: `{str(validation['descripcion_not_in_suyere']).lower()}`",
        "",
        "## Section Summary",
        "",
        "| Section | JSON Field | Changed | Missing in DOCX | Before Len | After Len |",
        "|---|---|---|---|---:|---:|",
    ]

    for section_name in SECTION_ORDER:
        info = summary_sections[section_name]
        report_lines.append(
            f"| {section_name} | `{info['json_field']}` | "
            f"{'yes' if info['changed'] else 'no'} | "
            f"{'yes' if info['missing_in_docx'] else 'no'} | "
            f"{info['before_len']} | {info['after_len']} |"
        )

    report_lines.extend([
        "",
        "## Key Before/After Previews (first 120 chars)",
        "",
    ])

    for sec in ["REZO", "SUYERE", "DESCRIPCION", "NACE", "ESHU"]:
        field = summary_sections[sec]["json_field"]
        before = str(before_content.get(field, "") or "")
        after = str(content.get(field, "") or "")
        report_lines.append(f"- {sec}/{field} before120: `{before[:120]}`")
        report_lines.append(f"- {sec}/{field} after120: `{after[:120]}`")
        report_lines.append("")

    REPORT_MD.write_text("\n".join(report_lines).rstrip() + "\n", encoding="utf-8")

    print("Baba Ejiogbe reimport completed.")
    print(f"Source DOCX: {docx_path}")
    print(f"Target key: {target_key}")
    print(f"Changed sections: {changed_count}/{total_sections}")
    print(f"Missing DOCX sections left unchanged: {missing_count}")
    print(f"Backup: {backup_path}")
    print(f"Report: {REPORT_MD}")
    print(f"Diff:   {DIFF_MD}")
    print(f"Summary:{SUMMARY_JSON}")
    print("assets/odu_content.json NOT modified.")


if __name__ == "__main__":
    main()
