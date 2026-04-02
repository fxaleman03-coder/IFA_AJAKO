#!/usr/bin/env python3
"""Prepare final migration candidate from cleaned DOCX collapsed corpus.

Inputs:
- build/odu_content_v2_collapsed.json
- build/recoverable_canonical_review.json

Outputs:
- build/odu_content_v2_ready.json
- build/odu_migration_report.md
- build/odu_migration_diff.md

Safety:
- Does NOT modify assets/odu_content.json
- Does NOT modify assets/odu_content_patched.json
"""

from __future__ import annotations

import importlib.util
import json
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple


ROOT = Path(__file__).resolve().parents[1]
IN_COLLAPSED = ROOT / "build" / "odu_content_v2_collapsed.json"
IN_REVIEW = ROOT / "build" / "recoverable_canonical_review.json"

OUT_READY = ROOT / "build" / "odu_content_v2_ready.json"
OUT_REPORT = ROOT / "build" / "odu_migration_report.md"
OUT_DIFF = ROOT / "build" / "odu_migration_diff.md"


REQUIRED_SOURCE_SECTIONS = [
    "descripcion",
    "nace",
    "obras",
    "diceIfa",
    "ewes",
    "refranes",
    "eshu",
    "historiasYPatakies",
]

APP_CONTENT_KEYS = [
    "name",
    "rezoYoruba",
    "suyereYoruba",
    "suyereEspanol",
    "nace",
    "descripcion",
    "ewes",
    "eshu",
    "rezosYSuyeres",
    "obrasYEbbo",
    "diceIfa",
    "refranes",
    "historiasYPatakies",
]


@dataclass
class AcceptItem:
    heading: str
    source_file: str
    guessed_canonical_odu: str
    recommendation: str


def load_importer_module():
    importer_path = ROOT / "scripts" / "import_all_odus_from_docx.py"
    spec = importlib.util.spec_from_file_location("odu_importer", importer_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load importer module from {importer_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _str(value) -> str:
    return value if isinstance(value, str) else ""


def _normalize_name(importer, text: str) -> str:
    return importer.normalize_upper_header(text or "")


def _find_heading_index(importer, paragraphs: List[str], heading: str) -> Optional[int]:
    target = _normalize_name(importer, heading)
    for i, p in enumerate(paragraphs):
        if _normalize_name(importer, p) == target:
            return i
    for i, p in enumerate(paragraphs):
        pn = _normalize_name(importer, p)
        if target and target in pn:
            return i
    return None


def _find_block_end(importer, paragraphs: List[str], start_idx: int, heading: str) -> int:
    target = _normalize_name(importer, heading)
    for i in range(start_idx + 1, len(paragraphs)):
        line = (paragraphs[i] or "").replace("\u00A0", " ").rstrip()
        status, _ = importer.classify_odu_boundary_heading(line)
        if status not in {"accepted", "ambiguous", "rejected"}:
            continue
        if _normalize_name(importer, line) == target:
            continue
        if status == "accepted":
            return i
        if importer.has_nearby_section_heading(paragraphs, i):
            return i
    return len(paragraphs)


def _extract_forced_entry(importer, item: AcceptItem) -> Tuple[dict, Dict[str, int], int]:
    source_path = ROOT / item.source_file
    if not source_path.exists():
        raise FileNotFoundError(f"Source DOCX not found for accepted candidate: {source_path}")

    paragraphs = importer.load_docx_paragraphs(source_path)
    start = _find_heading_index(importer, paragraphs, item.heading)
    if start is None:
        raise ValueError(f"Heading not found in source DOCX: {item.heading} ({item.source_file})")
    end = _find_block_end(importer, paragraphs, start, item.heading)
    segment = paragraphs[start:end]

    canonical_name = _normalize_name(importer, item.guessed_canonical_odu or item.heading)
    if not canonical_name:
        raise ValueError(f"Empty canonical name after normalization for heading: {item.heading}")

    acc = importer.OduAccumulator(odu_key=canonical_name, detected_name=canonical_name)
    acc.start_section("descripcion")

    for raw in segment:
        line = (raw or "").replace("\u00A0", " ").rstrip()
        sec = importer.detect_section_heading(line)
        if sec:
            _, sec_key, inline = sec
            acc.start_section(sec_key, inline_text=inline)
        else:
            acc.append_line(line)
        acc.set_order_if_found(line)

    entry, _repeat_counts = acc.to_entry()
    entry["odu_key"] = canonical_name
    entry["content"]["name"] = canonical_name
    entry["source_file"] = item.source_file
    entry["family_guess"] = importer.family_guess_from_filename(source_path)
    entry["canonical_key"] = canonical_name
    entry["canonical_resolution_method"] = "manual_accept_from_recoverable_canonical"
    entry["canonical_resolution_input"] = item.heading

    section_lengths = {}
    for section_key in importer.SECTION_KEYS.values():
        section_lengths[section_key] = len(_str(entry["content"].get(section_key, "")))

    return entry, section_lengths, len(segment)


def _entry_to_app_schema(
    importer,
    entry: dict,
) -> Tuple[dict, int]:
    content = entry.get("content", {})
    missing_filled = 0

    for sec in REQUIRED_SOURCE_SECTIONS:
        if sec not in content:
            content[sec] = ""
            missing_filled += 1

    name = _normalize_name(importer, _str(content.get("name")) or _str(entry.get("odu_key")))

    app_content = {
        "name": name,
        "rezoYoruba": _str(content.get("rezoYoruba")),
        "suyereYoruba": _str(content.get("suyereYoruba")),
        "suyereEspanol": _str(content.get("suyereEspanol")),
        "nace": _str(content.get("nace")),
        "descripcion": _str(content.get("descripcion")),
        "ewes": _str(content.get("ewes")),
        "eshu": _str(content.get("eshu")),
        "rezosYSuyeres": _str(content.get("rezosYSuyeres")),
        "obrasYEbbo": _str(content.get("obrasYEbbo")) or _str(content.get("obras")),
        "diceIfa": _str(content.get("diceIfa")),
        "refranes": _str(content.get("refranes")),
        "historiasYPatakies": _str(content.get("historiasYPatakies")),
    }

    for key in APP_CONTENT_KEYS:
        if key not in app_content:
            app_content[key] = ""
            missing_filled += 1

    app_entry = {
        "content": app_content,
        "patakies": entry.get("patakies", [] if isinstance(entry.get("patakies"), list) else []),
        "patakiesContent": entry.get("patakiesContent", {}),
    }

    if not isinstance(app_entry["patakies"], list):
        app_entry["patakies"] = []
    if not isinstance(app_entry["patakiesContent"], dict):
        app_entry["patakiesContent"] = {}

    return app_entry, missing_filled


def main() -> None:
    for p in [IN_COLLAPSED, IN_REVIEW]:
        if not p.exists():
            raise SystemExit(f"Missing required input: {p}")

    importer = load_importer_module()

    collapsed_payload = json.loads(IN_COLLAPSED.read_text(encoding="utf-8"))
    collapsed_entries: List[dict] = collapsed_payload.get("odus", [])

    review_payload = json.loads(IN_REVIEW.read_text(encoding="utf-8"))
    accepts_raw = [
        x
        for x in review_payload.get("items", [])
        if isinstance(x, dict) and x.get("recommendation") == "ACCEPT_AS_NEW_CANONICAL"
    ]
    accepts = [
        AcceptItem(
            heading=_str(x.get("heading")),
            source_file=_str(x.get("source_file")),
            guessed_canonical_odu=_str(x.get("guessed_canonical_odu")),
            recommendation=_str(x.get("recommendation")),
        )
        for x in accepts_raw
    ]

    existing_canonical = {
        _normalize_name(importer, _str(e.get("canonical_key")) or _str(e.get("odu_key")))
        for e in collapsed_entries
    }

    inserted_entries: List[dict] = []
    inserted_meta: List[dict] = []
    for item in accepts:
        canonical_name = _normalize_name(importer, item.guessed_canonical_odu or item.heading)
        if canonical_name in existing_canonical:
            inserted_meta.append(
                {
                    "heading": item.heading,
                    "canonical_name": canonical_name,
                    "source_file": item.source_file,
                    "inserted": False,
                    "reason": "already_exists_in_collapsed",
                }
            )
            continue

        entry, section_lengths, segment_paragraphs = _extract_forced_entry(importer, item)
        collapsed_entries.append(entry)
        existing_canonical.add(canonical_name)
        inserted_entries.append(entry)
        inserted_meta.append(
            {
                "heading": item.heading,
                "canonical_name": canonical_name,
                "source_file": item.source_file,
                "inserted": True,
                "reason": "accepted_from_recoverable_canonical",
                "segment_paragraphs": segment_paragraphs,
                "section_lengths": section_lengths,
            }
        )

    # Convert to app-compatible schema.
    app_odu_map: Dict[str, dict] = {}
    duplicate_keys: List[str] = []
    missing_sections_filled = 0

    canonical_groups: Dict[str, List[str]] = defaultdict(list)
    families: Dict[str, int] = defaultdict(int)

    for entry in collapsed_entries:
        key = _normalize_name(importer, _str(entry.get("odu_key")))
        if not key:
            continue
        if key in app_odu_map:
            duplicate_keys.append(key)
            continue

        app_entry, filled_count = _entry_to_app_schema(importer, entry)
        missing_sections_filled += filled_count
        app_odu_map[key] = app_entry

        canonical = importer.canonicalize_heading_for_grouping(key) or key
        canonical_groups[canonical].append(key)
        first_tok = canonical.split()[0] if canonical else "UNKNOWN"
        fam = importer.map_family_token(first_tok) or first_tok
        families[fam] += 1

    duplicate_canonical_keys = sorted([k for k, v in canonical_groups.items() if len(v) > 1])

    ready_payload = {
        "version": 1,
        "odu": dict(sorted(app_odu_map.items(), key=lambda kv: kv[0])),
    }
    OUT_READY.write_text(json.dumps(ready_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    family_sorted = sorted(families.items(), key=lambda kv: (kv[1], kv[0]))

    report_lines = [
        "# Odù Migration Report",
        "",
        f"- Input collapsed dataset: `{IN_COLLAPSED}`",
        f"- Input review packet: `{IN_REVIEW}`",
        f"- Output ready dataset: `{OUT_READY}`",
        "",
        "## Summary",
        "",
        f"- Total odù (ready): **{len(app_odu_map)}**",
        f"- Families detected: **{len(families)}**",
        f"- Duplicate keys: **{len(duplicate_keys)}**",
        f"- Duplicate canonical keys: **{len(duplicate_canonical_keys)}**",
        f"- Missing sections filled: **{missing_sections_filled}**",
        f"- ACCEPT entries requested: **{len(accepts)}**",
        f"- ACCEPT entries inserted: **{sum(1 for x in inserted_meta if x['inserted'])}**",
        "",
        "## Families (Ascending by Count)",
        "",
    ]
    for fam, count in family_sorted:
        report_lines.append(f"- {fam}: {count}")

    report_lines.extend(["", "## Inserted ACCEPT Entries", ""])
    for m in inserted_meta:
        report_lines.append(
            f"- `{m['canonical_name']}` from `{m['source_file']}` inserted={m['inserted']} reason={m['reason']}"
        )

    if duplicate_keys:
        report_lines.extend(["", "## Duplicate Keys", ""])
        report_lines.extend([f"- {k}" for k in sorted(set(duplicate_keys))])

    if duplicate_canonical_keys:
        report_lines.extend(["", "## Duplicate Canonical Keys", ""])
        for ck in duplicate_canonical_keys:
            members = ", ".join(sorted(canonical_groups.get(ck, [])))
            report_lines.append(f"- `{ck}` -> {members}")

    OUT_REPORT.write_text("\n".join(report_lines).rstrip() + "\n", encoding="utf-8")

    diff_lines = [
        "# Odù Migration Diff",
        "",
        "## Inserted ACCEPT Entries Details",
        "",
    ]
    for m in inserted_meta:
        diff_lines.append(f"### {m['canonical_name']}")
        diff_lines.append(f"- source_file: `{m['source_file']}`")
        diff_lines.append(f"- inserted: `{m['inserted']}`")
        diff_lines.append(f"- reason: `{m['reason']}`")
        if m["inserted"]:
            sec_lengths = m.get("section_lengths", {})
            diff_lines.append("- section lengths:")
            for sec in ["descripcion", "nace", "obras", "diceIfa", "ewes", "refranes", "eshu", "historiasYPatakies"]:
                diff_lines.append(f"  - {sec}: {sec_lengths.get(sec, 0)}")
        diff_lines.append("")

    OUT_DIFF.write_text("\n".join(diff_lines).rstrip() + "\n", encoding="utf-8")

    print(f"total odù: {len(app_odu_map)}")
    print(f"families detected: {len(families)}")
    print(f"duplicate keys: {len(duplicate_keys)}")
    print(f"duplicate canonical keys: {len(duplicate_canonical_keys)}")
    print(f"missing sections filled: {missing_sections_filled}")
    print(f"Wrote: {OUT_READY}")
    print(f"Wrote: {OUT_REPORT}")
    print(f"Wrote: {OUT_DIFF}")


if __name__ == "__main__":
    main()
