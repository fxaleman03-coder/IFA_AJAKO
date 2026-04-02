#!/usr/bin/env python3
import json
import re
import subprocess
import unicodedata
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = Path(
    "/Users/fxaleman03gmail.com/Library/CloudStorage/OneDrive-Personal/3- IFA AYAKO/1-BABA EJIOGBE"
)
APP_CORPUS_PATH = ROOT / "assets/odu_content_patched.json"

OUT_MD = ROOT / "build/baba_ejiogbe_section_audit.md"
OUT_JSON = ROOT / "build/baba_ejiogbe_section_audit.json"

SECTION_ORDER = [
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

APP_FIELD_BY_SECTION = {
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


def fold(text: str) -> str:
    text = text or ""
    text = text.upper().strip()
    text = "".join(
        c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn"
    )
    text = re.sub(r"\s+", " ", text).strip()
    return text


def norm_for_search(text: str) -> str:
    text = fold(text)
    text = re.sub(r"[^A-Z0-9 ]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def pick_source_file(source_dir: Path) -> Path:
    if not source_dir.exists() or not source_dir.is_dir():
        raise RuntimeError(f"Source directory does not exist: {source_dir}")

    candidates = sorted([p for p in source_dir.iterdir() if p.is_file()])
    priority_names = [
        "1- EJIOGBE.docx",
        "1- EJIOGBE.doc",
    ]
    for name in priority_names:
        for p in candidates:
            if p.name == name:
                return p

    for p in candidates:
        name_fold = fold(p.name)
        if "EJIOGBE" in name_fold and p.suffix.lower() in {".docx", ".doc"}:
            return p

    raise RuntimeError(f"No EJIOGBE .doc/.docx file found in {source_dir}")


def extract_text_from_doc(path: Path) -> str:
    # Use macOS textutil for .doc/.docx conversion, preserving line structure.
    result = subprocess.run(
        ["textutil", "-convert", "txt", "-stdout", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"textutil failed for {path} with code {result.returncode}: {result.stderr.strip()}"
        )
    return result.stdout


def detect_heading(line: str) -> Tuple[Optional[str], str]:
    raw = line.strip()
    if not raw:
        return None, ""

    f = fold(raw)
    if not f:
        return None, ""

    # REZO / SUYERE support inline content on the same line.
    m = re.match(r"^REZO\s*:?\s*(.*)$", f)
    if m:
        return "REZO", raw[m.start(1) :].strip() if m.group(1) else ""

    m = re.match(r"^SUYERE\s*:?\s*(.*)$", f)
    if m:
        return "SUYERE", raw[m.start(1) :].strip() if m.group(1) else ""

    if re.match(r"^EN ESTE ODU NACE\s*:?\s*$", f):
        return "EN ESTE ODU NACE", ""
    if re.match(r"^DESCRIPCION DEL ODU\b.*$", f):
        return "DESCRIPCIÓN DEL ODU", ""
    if re.match(r"^PREDICCIONES DEL ODU\b.*$", f):
        return "PREDICCIONES DEL ODU", ""
    if re.match(r"^ESTE ODU PROHIBE\b.*$", f):
        return "ESTE ODU PROHIBE", ""
    if re.match(r"^ESTE ODU RECOMIENDA\b.*$", f):
        return "ESTE ODU RECOMIENDA", ""
    if re.match(r"^OBRAS DEL ODU\b.*$", f):
        return "OBRAS DEL ODU", ""
    if re.match(r"^DICE IFA\b.*$", f):
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


def parse_source(text: str) -> Dict:
    lines = text.splitlines()
    pre_header_lines: List[str] = []
    section_blocks: Dict[str, List[str]] = {k: [] for k in SECTION_ORDER}

    first_section_seen = False
    current_section: Optional[str] = None
    current_lines: List[str] = []

    def flush_current() -> None:
        nonlocal current_section, current_lines
        if current_section is not None:
            content = "\n".join(current_lines).strip()
            if content:
                section_blocks[current_section].append(content)
        current_section = None
        current_lines = []

    for line in lines:
        section, inline = detect_heading(line)
        if section is not None:
            first_section_seen = True
            flush_current()
            current_section = section
            current_lines = []
            if inline:
                current_lines.append(inline)
            continue

        if not first_section_seen:
            if line.strip():
                pre_header_lines.append(line.strip())
            continue

        if current_section is not None:
            current_lines.append(line.rstrip())

    flush_current()

    main_name = pre_header_lines[0] if pre_header_lines else ""
    aliases = pre_header_lines[1:] if len(pre_header_lines) > 1 else []

    sections = {}
    for section_name in SECTION_ORDER:
        blocks = section_blocks.get(section_name, [])
        sections[section_name] = {
            "blocks": blocks,
            "combined": "\n\n".join(blocks).strip() if blocks else "",
            "present": bool(blocks),
            "block_count": len(blocks),
        }

    return {
        "main_name": main_name,
        "aliases": aliases,
        "sections": sections,
    }


def find_app_candidate(corpus: Dict) -> Tuple[Optional[str], List[str]]:
    candidates = []
    for key, value in corpus.items():
        if not isinstance(key, str) or not isinstance(value, dict):
            continue
        content = value.get("content", {})
        name = content.get("name", "") if isinstance(content, dict) else ""
        key_f = fold(key)
        name_f = fold(name) if isinstance(name, str) else ""

        trigger = any(
            token in key_f or token in name_f
            for token in ["BABA OGBE", "BABA EJIOGBE", "EJIOGBE", "EJI OGBE", "OGBE MEJI"]
        )
        if trigger:
            candidates.append(key)

    candidates = sorted(set(candidates))
    if len(candidates) == 1:
        return candidates[0], candidates
    return None, candidates


def app_field_text(content: Dict, field: str) -> str:
    value = content.get(field, "")
    return value if isinstance(value, str) else ""


def first_probe_line(section_text: str) -> str:
    for line in section_text.splitlines():
        t = line.strip()
        if len(t) >= 25:
            return t[:100]
    return ""


def audit_against_app(source_info: Dict, app_entry: Dict) -> Dict:
    content = app_entry.get("content", {}) if isinstance(app_entry, dict) else {}
    if not isinstance(content, dict):
        content = {}

    missing_sections_in_app: List[str] = []
    misplaced_sections_in_app: List[Dict] = []

    app_texts = {field: app_field_text(content, field) for field in set(APP_FIELD_BY_SECTION.values())}

    for section in SECTION_ORDER:
        section_info = source_info["sections"][section]
        source_has = section_info["present"]
        expected_field = APP_FIELD_BY_SECTION[section]
        app_has = bool(app_texts.get(expected_field, "").strip())
        if source_has and not app_has:
            missing_sections_in_app.append(section)

            probe = first_probe_line(section_info["combined"])
            if probe:
                probe_norm = norm_for_search(probe)
                for other_field, other_text in app_texts.items():
                    if other_field == expected_field:
                        continue
                    if probe_norm and probe_norm in norm_for_search(other_text):
                        misplaced_sections_in_app.append(
                            {
                                "section": section,
                                "expected_field": expected_field,
                                "found_in_field": other_field,
                                "evidence_probe": probe,
                            }
                        )
                        break

    # Contamination check: heading labels inside wrong app fields.
    heading_to_expected = {
        "REZO": "rezoYoruba",
        "SUYERE": "suyereYoruba",
        "EN ESTE ODU NACE": "nace",
        "DESCRIPCION DEL ODU": "descripcion",
        "PREDICCIONES DEL ODU": "predicciones",
        "ESTE ODU PROHIBE": "prohibiciones",
        "ESTE ODU RECOMIENDA": "recomendaciones",
        "OBRAS DEL ODU": "obras",
        "DICE IFA": "diceIfa",
        "EWES DEL ODU": "ewes",
        "REFRANES DEL ODU": "refranes",
        "ESHU ELEGBA DEL ODU": "eshu",
        "HISTORIAS O PATAKINES DEL ODU": "historiasYPatakies",
    }
    for field, text in app_texts.items():
        text_fold = fold(text)
        for heading, expected in heading_to_expected.items():
            if expected == field:
                continue
            if heading and heading in text_fold:
                misplaced_sections_in_app.append(
                    {
                        "section": heading,
                        "expected_field": expected,
                        "found_in_field": field,
                        "evidence_probe": f"heading_detected:{heading}",
                    }
                )

    # Deduplicate misplaced records.
    seen = set()
    dedup = []
    for item in misplaced_sections_in_app:
        key = (
            item["section"],
            item["expected_field"],
            item["found_in_field"],
            item["evidence_probe"][:80],
        )
        if key in seen:
            continue
        seen.add(key)
        dedup.append(item)
    misplaced_sections_in_app = dedup

    aliases = source_info["aliases"]
    app_aliases = content.get("aliases")
    app_has_aliases = isinstance(app_aliases, list) and len(app_aliases) > 0
    alias_structure_needed = bool(aliases) and not app_has_aliases

    template_ready = (
        not missing_sections_in_app
        and not misplaced_sections_in_app
        and not alias_structure_needed
    )

    return {
        "missing_sections_in_app": missing_sections_in_app,
        "misplaced_sections_in_app": misplaced_sections_in_app,
        "alias_structure_needed": alias_structure_needed,
        "template_ready": template_ready,
    }


def build_report(audit: Dict) -> None:
    OUT_JSON.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = []
    lines.append("# Baba Ejiogbe Section Audit")
    lines.append("")
    lines.append(f"- Source file used: `{audit['source_file_used']}`")
    lines.append(f"- Header main_name: `{audit['main_name']}`")
    lines.append(f"- Aliases count: **{audit['aliases_count']}**")
    if audit["aliases"]:
        lines.append("- Aliases:")
        for alias in audit["aliases"]:
            lines.append(f"  - `{alias}`")
    else:
        lines.append("- Aliases: (none)")
    lines.append("")
    lines.append(f"- Target app odù key: `{audit.get('target_odu_key') or 'N/A'}`")
    lines.append(f"- Target app odù name: `{audit.get('target_odu_name') or 'N/A'}`")
    lines.append("")
    lines.append("## DOCX Section Presence")
    for section in SECTION_ORDER:
        s = audit["docx_sections"][section]
        lines.append(
            f"- `{section}`: present={str(s['present']).lower()}, blocks={s['block_count']}"
        )
    lines.append("")
    lines.append("## Findings")
    lines.append(
        f"- Missing sections in app: {audit['missing_sections_in_app'] if audit['missing_sections_in_app'] else '[]'}"
    )
    lines.append(
        f"- Misplaced sections in app: {audit['misplaced_sections_in_app'] if audit['misplaced_sections_in_app'] else '[]'}"
    )
    lines.append(
        f"- Alias structure needed: {'YES' if audit['alias_structure_needed'] else 'NO'}"
    )
    lines.append(f"- Template ready: {'YES' if audit['template_ready'] else 'NO'}")
    lines.append("")

    OUT_MD.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    source_file = pick_source_file(SOURCE_DIR)
    source_text = extract_text_from_doc(source_file)
    source_info = parse_source(source_text)

    app_data = json.loads(APP_CORPUS_PATH.read_text(encoding="utf-8"))
    app_odu = app_data.get("odu", {}) if isinstance(app_data, dict) else {}
    if not isinstance(app_odu, dict):
        raise RuntimeError("Invalid app corpus schema.")

    target_key, candidates = find_app_candidate(app_odu)
    if target_key is None:
        audit = {
            "source_file_used": str(source_file),
            "main_name": source_info["main_name"],
            "aliases_count": len(source_info["aliases"]),
            "aliases": source_info["aliases"],
            "target_odu_key": None,
            "target_odu_name": None,
            "candidate_keys_found": candidates,
            "error": "Expected a single Baba Ejiogbe app candidate. Stopped due to ambiguity/no-match.",
            "docx_sections": {
                section: {
                    "present": source_info["sections"][section]["present"],
                    "block_count": source_info["sections"][section]["block_count"],
                }
                for section in SECTION_ORDER
            },
            "missing_sections_in_app": [],
            "misplaced_sections_in_app": [],
            "alias_structure_needed": bool(source_info["aliases"]),
            "template_ready": False,
        }
        build_report(audit)
        return

    app_entry = app_odu[target_key]
    app_content = app_entry.get("content", {}) if isinstance(app_entry, dict) else {}
    app_name = app_content.get("name", "") if isinstance(app_content, dict) else ""

    compare = audit_against_app(source_info, app_entry)

    audit = {
        "source_file_used": str(source_file),
        "main_name": source_info["main_name"],
        "aliases_count": len(source_info["aliases"]),
        "aliases": source_info["aliases"],
        "target_odu_key": target_key,
        "target_odu_name": app_name,
        "candidate_keys_found": candidates,
        "docx_sections": {
            section: {
                "present": source_info["sections"][section]["present"],
                "block_count": source_info["sections"][section]["block_count"],
                "multiple_blocks": source_info["sections"][section]["block_count"] > 1,
            }
            for section in SECTION_ORDER
        },
        "missing_sections_in_app": compare["missing_sections_in_app"],
        "misplaced_sections_in_app": compare["misplaced_sections_in_app"],
        "alias_structure_needed": compare["alias_structure_needed"],
        "template_ready": compare["template_ready"],
    }

    build_report(audit)

    print("target_odu_key:", audit["target_odu_key"])
    print("source_file_used:", audit["source_file_used"])
    print("header_main_name:", audit["main_name"])
    print("aliases_count:", audit["aliases_count"])
    print("aliases_list:", audit["aliases"])
    print("missing_sections_in_app:", audit["missing_sections_in_app"])
    print("misplaced_sections_in_app:", audit["misplaced_sections_in_app"])
    print("alias_structure_needed:", "YES" if audit["alias_structure_needed"] else "NO")
    print("template_ready:", "YES" if audit["template_ready"] else "NO")


if __name__ == "__main__":
    main()
