#!/usr/bin/env python3
import difflib
import json
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[1]

DOCX_PATH = Path(
    "/Users/fxaleman03gmail.com/Library/CloudStorage/OneDrive-Personal/3- IFA AYAKO/1-BABA EJIOGBE/1- EJIOGBE.docx"
)
ASSET_PATH = ROOT / "assets/odu_content_patched.json"
BUILD_JSON_PATH = ROOT / "build/odu_content_patched.json"

REPORT_MD = ROOT / "build/baba_ejiogbe_rebuild_report.md"
DIFF_MD = ROOT / "build/baba_ejiogbe_rebuild_diff.md"
SUMMARY_JSON = ROOT / "build/baba_ejiogbe_rebuild_summary.json"

TARGET_KEY = "BABA OGBE"

SECTION_LABELS = [
    "REZO",
    "SUYERE",
    "EN ESTE ODU NACE",
    "DESCRIPCIÓN DEL ODU",
    "PREDICCIONES DEL ODU",
    "ESTE ODU PROHIBE",
    "ESTE ODU RECOMIENDA",
    "OBRAS DEL ODU",
    "DICE IFÁ / DICE IFA",
    "EWES DEL ODU",
    "REFRANES DEL ODU",
    "ESHU-ELEGBA DEL ODU",
    "HISTORIAS O PATAKINES DEL ODU",
]

JSON_FIELD_BY_SECTION = {
    "REZO": "rezoYoruba",
    "SUYERE": "suyereYoruba",
    "EN ESTE ODU NACE": "nace",
    "DESCRIPCIÓN DEL ODU": "descripcion",
    "PREDICCIONES DEL ODU": "predicciones",
    "ESTE ODU PROHIBE": "prohibiciones",
    "ESTE ODU RECOMIENDA": "recomendaciones",
    "OBRAS DEL ODU": "obras",
    "DICE IFÁ / DICE IFA": "diceIfa",
    "EWES DEL ODU": "ewes",
    "REFRANES DEL ODU": "refranes",
    "ESHU-ELEGBA DEL ODU": "eshu",
    "HISTORIAS O PATAKINES DEL ODU": "historiasYPatakies",
}

ALL_REBUILT_FIELDS = [
    "rezoYoruba",
    "suyereYoruba",
    "nace",
    "descripcion",
    "predicciones",
    "prohibiciones",
    "recomendaciones",
    "obras",
    "diceIfa",
    "ewes",
    "refranes",
    "eshu",
    "historiasYPatakies",
]

MISPLACED_HEADING_TOKENS = [
    "EN ESTE ODU NACE",
    "PREDICCIONES DEL ODU",
    "ESTE ODU PROHIBE",
    "ESTE ODU RECOMIENDA",
    "OBRAS DEL ODU",
    "DICE IFA",
    "EWES DEL ODU",
    "REFRANES DEL ODU",
    "ESHU-ELEGBA DEL ODU",
    "HISTORIAS O PATAKINES DEL ODU",
]


def fold(value: str) -> str:
    text = value.upper().strip()
    text = re.sub(r"\s+", " ", text)
    return text


def detect_section_heading(raw_line: str) -> Tuple[Optional[str], str]:
    raw = raw_line.strip()
    if not raw:
        return None, ""
    f = fold(raw)

    # Headings that often include inline content.
    m = re.match(r"^REZO\s*:?\s*(.*)$", f)
    if m:
        inline = raw[m.start(1) :].strip() if m.group(1) else ""
        return "REZO", inline

    m = re.match(r"^SUYERE\s*:?\s*(.*)$", f)
    if m:
        inline = raw[m.start(1) :].strip() if m.group(1) else ""
        return "SUYERE", inline

    if re.match(r"^EN ESTE ODU NACE\s*:?\s*$", f):
        return "EN ESTE ODU NACE", ""
    if re.match(r"^DESCRIPCIÓN DEL ODU\b.*$|^DESCRIPCION DEL ODU\b.*$", f):
        return "DESCRIPCIÓN DEL ODU", ""
    if re.match(r"^PREDICCIONES DEL ODU\b.*$", f):
        return "PREDICCIONES DEL ODU", ""
    if re.match(r"^ESTE ODU PROHIBE\b.*$", f):
        return "ESTE ODU PROHIBE", ""
    if re.match(r"^ESTE ODU RECOMIENDA\b.*$", f):
        return "ESTE ODU RECOMIENDA", ""
    if re.match(r"^OBRAS DEL ODU\b.*$", f):
        return "OBRAS DEL ODU", ""
    if re.match(r"^DICE IF[ÁA]\b.*$|^DICE IFA\b.*$", f):
        return "DICE IFÁ / DICE IFA", ""
    if re.match(r"^EWES DEL ODU\b.*$", f):
        return "EWES DEL ODU", ""
    if re.match(r"^REFRANES DEL ODU\b.*$", f):
        return "REFRANES DEL ODU", ""
    if re.match(r"^ESHU[\s\-–—]*ELEGBA DEL ODU\b.*$", f):
        return "ESHU-ELEGBA DEL ODU", ""
    if re.match(r"^HISTORIAS O PATAKINES DEL ODU\b.*$", f):
        return "HISTORIAS O PATAKINES DEL ODU", ""
    return None, ""


def parse_docx_sections(text: str) -> Dict:
    lines = text.splitlines()
    pre_section_header_lines: List[str] = []
    blocks_by_section: Dict[str, List[str]] = {label: [] for label in SECTION_LABELS}

    saw_first_section = False
    current_section: Optional[str] = None
    current_lines: List[str] = []

    def flush() -> None:
        nonlocal current_section, current_lines
        if current_section is not None:
            content = "\n".join(current_lines).strip()
            if content:
                blocks_by_section[current_section].append(content)
        current_section = None
        current_lines = []

    for line in lines:
        section, inline = detect_section_heading(line)
        if section is not None:
            saw_first_section = True
            flush()
            current_section = section
            current_lines = []
            if inline:
                current_lines.append(inline)
            continue

        if not saw_first_section:
            if line.strip():
                pre_section_header_lines.append(line.strip())
            continue

        if current_section is not None:
            current_lines.append(line.rstrip())
    flush()

    main_name = pre_section_header_lines[0] if pre_section_header_lines else ""
    aliases = pre_section_header_lines[1:] if len(pre_section_header_lines) > 1 else []

    combined_by_section = {}
    for section, blocks in blocks_by_section.items():
        combined_by_section[section] = "\n\n".join(blocks).strip() if blocks else ""

    return {
        "main_name": main_name,
        "aliases": aliases,
        "blocks_by_section": blocks_by_section,
        "combined_by_section": combined_by_section,
    }


def read_docx_text(docx_path: Path) -> Tuple[str, Path]:
    source_path = docx_path
    if not source_path.exists():
        # Same fixed folder only: tolerate renamed variant like "1- EJIOGBE.dcx.docx".
        parent = docx_path.parent
        pattern = re.compile(r"^1-\s*EJIOGBE.*\.docx$", re.IGNORECASE)
        candidates = sorted(
            [p for p in parent.iterdir() if p.is_file() and pattern.match(p.name)]
        )
        if len(candidates) == 1:
            source_path = candidates[0]
        else:
            raise RuntimeError(
                f"DOCX not found at expected path: {docx_path}. "
                f"Fallback candidates in fixed folder: {[str(c) for c in candidates]}"
            )

    cmd = ["textutil", "-convert", "txt", "-stdout", str(source_path)]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(
            f"textutil failed ({result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout, source_path


def ensure_single_target(data: Dict) -> None:
    odu = data.get("odu")
    if not isinstance(odu, dict):
        raise RuntimeError("Invalid schema: missing odu object.")
    if TARGET_KEY not in odu:
        raise RuntimeError(f"Target key not found: {TARGET_KEY}")


def clean_for_token_scan(text: str) -> str:
    return fold(text).replace("Á", "A")


def make_reports(
    backup_path: Path,
    source_file: Path,
    before_content: Dict,
    after_content: Dict,
    parsed: Dict,
) -> Dict:
    per_section = []
    for section in SECTION_LABELS:
        field = JSON_FIELD_BY_SECTION[section]
        before_text = before_content.get(field, "") if isinstance(before_content.get(field, ""), str) else ""
        after_text = after_content.get(field, "") if isinstance(after_content.get(field, ""), str) else ""
        per_section.append(
            {
                "section": section,
                "field": field,
                "before_len": len(before_text),
                "after_len": len(after_text),
                "changed": before_text != after_text,
                "docx_block_count": len(parsed["blocks_by_section"].get(section, [])),
                "docx_present": bool(parsed["blocks_by_section"].get(section, [])),
            }
        )

    changed_sections = [s["section"] for s in per_section if s["changed"]]
    missing_added = all(
        bool((after_content.get(field) or "").strip())
        for field in ["predicciones", "prohibiciones", "recomendaciones"]
    )

    desc_clean = True
    for token in ["PREDICCIONES DEL ODU", "ESTE ODU PROHIBE", "ESTE ODU RECOMIENDA"]:
        if token in clean_for_token_scan(after_content.get("descripcion", "")):
            desc_clean = False
            break
    eshu_clean = True
    for token in MISPLACED_HEADING_TOKENS:
        if token in clean_for_token_scan(after_content.get("eshu", "")):
            eshu_clean = False
            break
    historias_clean = True
    for token in MISPLACED_HEADING_TOKENS:
        if token in clean_for_token_scan(after_content.get("historiasYPatakies", "")):
            historias_clean = False
            break
    misplaced_cleaned = desc_clean and eshu_clean and historias_clean

    alias_stored = bool(after_content.get("mainName")) and isinstance(
        after_content.get("aliases"), list
    )

    summary = {
        "target_odu_key": TARGET_KEY,
        "source_file_used": str(source_file),
        "backup_path": str(backup_path),
        "main_name_extracted": parsed["main_name"],
        "aliases_extracted": parsed["aliases"],
        "aliases_count": len(parsed["aliases"]),
        "sections_rebuilt": ALL_REBUILT_FIELDS,
        "alias_structure_stored": alias_stored,
        "alias_storage_details": {
            "main_name_field": "content.mainName" if alias_stored else None,
            "aliases_field": "content.aliases" if alias_stored else None,
        },
        "missing_sections_added": missing_added,
        "misplaced_content_cleaned": misplaced_cleaned,
        "per_section_lengths": per_section,
    }
    SUMMARY_JSON.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    report_lines = [
        "# Baba Ejiogbe Rebuild Report",
        "",
        f"- Target odù key: `{TARGET_KEY}`",
        f"- Source file used: `{source_file}`",
        f"- Backup created: `{backup_path}`",
        f"- Main name extracted: `{parsed['main_name']}`",
        f"- Aliases extracted ({len(parsed['aliases'])}): `{parsed['aliases']}`",
        f"- Sections rebuilt: `{ALL_REBUILT_FIELDS}`",
        f"- Alias structure stored: `{'YES' if alias_stored else 'NO'}`",
        f"- Missing sections added (predicciones/prohibiciones/recomendaciones): `{'YES' if missing_added else 'NO'}`",
        f"- Misplaced content cleaned (descripcion/eshu/historiasYPatakies): `{'YES' if misplaced_cleaned else 'NO'}`",
        "",
        "## Per-Section Lengths",
    ]
    for item in per_section:
        report_lines.append(
            f"- {item['section']} ({item['field']}): {item['before_len']} -> {item['after_len']} | changed={str(item['changed']).lower()} | docx_blocks={item['docx_block_count']}"
        )
    REPORT_MD.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    diff_lines = [
        "# Baba Ejiogbe Rebuild Diff (before/after snippets)",
        "",
    ]
    for section in SECTION_LABELS:
        field = JSON_FIELD_BY_SECTION[section]
        before_text = before_content.get(field, "") if isinstance(before_content.get(field, ""), str) else ""
        after_text = after_content.get(field, "") if isinstance(after_content.get(field, ""), str) else ""
        diff_lines.append(f"## {section} (`{field}`)")
        diff_lines.append(f"- before_len={len(before_text)}")
        diff_lines.append(f"- after_len={len(after_text)}")
        diff_lines.append("")
        before_lines = before_text.splitlines()[:60]
        after_lines = after_text.splitlines()[:60]
        unified = list(
            difflib.unified_diff(
                before_lines,
                after_lines,
                fromfile="before",
                tofile="after",
                lineterm="",
            )
        )
        if not unified:
            diff_lines.append("_No changes_")
        else:
            diff_lines.append("```diff")
            diff_lines.extend(unified[:220])
            diff_lines.append("```")
        diff_lines.append("")
    DIFF_MD.write_text("\n".join(diff_lines), encoding="utf-8")

    return summary


def main() -> None:
    source_text, source_path_used = read_docx_text(DOCX_PATH)
    parsed = parse_docx_sections(source_text)

    data = json.loads(ASSET_PATH.read_text(encoding="utf-8"))
    ensure_single_target(data)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = ASSET_PATH.with_name(
        f"odu_content_patched.json.bak_baba_ejiogbe_rebuild_{timestamp}"
    )
    shutil.copy2(ASSET_PATH, backup_path)

    odu = data["odu"]
    entry = odu[TARGET_KEY]
    if not isinstance(entry, dict):
        raise RuntimeError(f"Invalid entry format for {TARGET_KEY}")
    content = entry.get("content")
    if not isinstance(content, dict):
        raise RuntimeError(f"Invalid content format for {TARGET_KEY}")

    before_content = json.loads(json.dumps(content, ensure_ascii=False))

    # Rebuild only requested fields from DOCX.
    for section, field in JSON_FIELD_BY_SECTION.items():
        content[field] = parsed["combined_by_section"].get(section, "")

    # Keep UI display name unchanged, but store alias structure.
    content["mainName"] = parsed["main_name"]
    content["aliases"] = parsed["aliases"]

    # Keep legacy fields in sync with rebuilt content used by current UI.
    content["obrasYEbbo"] = content.get("obras", "")
    rezos = content.get("rezoYoruba", "")
    suyere = content.get("suyereYoruba", "")
    rezos_merged = "\n\n".join([x for x in [rezos, suyere] if isinstance(x, str) and x.strip()])
    content["rezosYSuyeres"] = rezos_merged
    if "suyereEspanol" not in content or not isinstance(content.get("suyereEspanol"), str):
        content["suyereEspanol"] = ""

    after_content = json.loads(json.dumps(content, ensure_ascii=False))

    # Guardrail: only one odù entry should change.
    original_all = json.loads(backup_path.read_text(encoding="utf-8"))
    changed_keys = []
    for key in data.get("odu", {}):
        before = original_all.get("odu", {}).get(key)
        after = data.get("odu", {}).get(key)
        if before != after:
            changed_keys.append(key)
    if changed_keys != [TARGET_KEY]:
        raise RuntimeError(
            f"Safety check failed: changed keys={changed_keys}, expected only [{TARGET_KEY}]"
        )

    BUILD_JSON_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    shutil.copy2(BUILD_JSON_PATH, ASSET_PATH)

    summary = make_reports(
        backup_path=backup_path,
        source_file=source_path_used,
        before_content=before_content,
        after_content=after_content,
        parsed=parsed,
    )

    print("target_odu_key:", summary["target_odu_key"])
    print("sections_rebuilt:", summary["sections_rebuilt"])
    print("alias_stored:", "YES" if summary["alias_structure_stored"] else "NO")
    print(
        "missing_sections_added:",
        "YES" if summary["missing_sections_added"] else "NO",
    )
    print(
        "misplaced_content_cleaned:",
        "YES" if summary["misplaced_content_cleaned"] else "NO",
    )


if __name__ == "__main__":
    main()
