#!/usr/bin/env python3
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path
from typing import Dict, List

ROOT = Path(__file__).resolve().parents[1]

UNRESOLVED_PATH = ROOT / "build/odu_v2_unresolved_review.json"
V2_PATH = ROOT / "assets/odu_content_v2_ready.json"
PATCHED_PATH = ROOT / "assets/odu_content_patched.json"
COMPAT_PATH = ROOT / "assets/odu_key_compat_map.json"

OUT_MD = ROOT / "build/odu_v2_ogbe_manual_packet.md"
OUT_JSON = ROOT / "build/odu_v2_ogbe_manual_packet.json"

_SAFE_SECOND_TOKEN_MAP = {
    "FUN": "OFUN",
    "KANA": "OKANA",
    "ROSO": "IROSO",
    "SHE": "OSHE",
    "YEKU": "OYEKU",
    "DI": "ODI",
    "KA": "IKA",
    "SA": "OSA",
}


def _load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _normalize(text: str) -> str:
    text = (text or "").upper().strip()
    text = "".join(
        c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn"
    )
    text = text.replace("_", " ").replace("-", " ")
    text = re.sub(r"[^A-Z0-9 ]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _preview(text: str, size: int = 300) -> str:
    text = (text or "").strip()
    if len(text) <= size:
        return text
    return text[:size].rstrip() + "..."


def _section_preview(corpus_entry: dict, section: str) -> str:
    content = corpus_entry.get("content") if isinstance(corpus_entry, dict) else None
    if not isinstance(content, dict):
        return ""
    raw = content.get(section)
    return _preview(raw if isinstance(raw, str) else "")


def _recommendation(old_key: str, candidates: List[dict]) -> Dict[str, str]:
    if not candidates:
        return {
            "confidence": "NO_MATCH",
            "recommended_action": "LEAVE_UNMAPPED",
            "reason": "no_v2_candidates",
        }

    top = candidates[0]
    top_key = top.get("key", "")
    score = int(top.get("score", 0) or 0)

    old_tokens = _normalize(old_key).split()
    top_tokens = _normalize(top_key).split()

    if len(old_tokens) >= 2 and len(top_tokens) >= 2:
        expected = _SAFE_SECOND_TOKEN_MAP.get(old_tokens[1])
        if expected and top_tokens[1] == expected and score >= 90:
            return {
                "confidence": "SAFE_MATCH",
                "recommended_action": "ADD_TO_COMPAT_MAP",
                "reason": "strong_family_pair_token_match",
            }

    if score >= 80:
        return {
            "confidence": "NEEDS_REVIEW",
            "recommended_action": "MANUAL_CONTENT_IMPORT_NEEDED",
            "reason": "candidate_exists_but_not_safe_token_map",
        }

    return {
        "confidence": "NO_MATCH",
        "recommended_action": "LEAVE_UNMAPPED",
        "reason": "weak_or_ambiguous_similarity",
    }


def main() -> None:
    unresolved = _load_json(UNRESOLVED_PATH)
    v2_data = _load_json(V2_PATH)
    patched_data = _load_json(PATCHED_PATH)
    compat_data = _load_json(COMPAT_PATH)

    unresolved_entries = unresolved.get("entries", []) if isinstance(unresolved, dict) else []
    v2_odu = v2_data.get("odu", {}) if isinstance(v2_data, dict) else {}
    patched_odu = patched_data.get("odu", {}) if isinstance(patched_data, dict) else {}
    compat_map = compat_data if isinstance(compat_data, dict) else {}

    if not isinstance(v2_odu, dict) or not isinstance(patched_odu, dict):
        raise RuntimeError("Invalid corpus schema.")

    ogbe_entries = [
        e for e in unresolved_entries
        if isinstance(e, dict) and e.get("family_guess") == "OGBE"
    ]
    ogbe_entries.sort(key=lambda e: e.get("old_key", ""))

    packet_entries = []
    counts = Counter()

    for entry in ogbe_entries:
        old_key = str(entry.get("old_key", "")).strip()
        normalized = str(entry.get("normalized", "")).strip()
        family_guess = str(entry.get("family_guess", "")).strip()
        candidates = entry.get("suggested_nearest_v2_candidates", [])
        if not isinstance(candidates, list):
            candidates = []
        top3 = [c for c in candidates if isinstance(c, dict)][:3]

        rec = _recommendation(old_key, top3)
        counts[rec["recommended_action"]] += 1

        patched_exists = old_key in patched_odu
        patched_entry = patched_odu.get(old_key, {}) if patched_exists else {}

        top_candidate_key = top3[0].get("key", "") if top3 else ""
        v2_entry = v2_odu.get(top_candidate_key, {}) if top_candidate_key else {}

        packet_entries.append(
            {
                "old_key": old_key,
                "normalized_form": normalized,
                "family_guess": family_guess,
                "exists_in_patched_corpus": patched_exists,
                "already_in_compat_map": old_key in compat_map,
                "top_3_nearest_v2_candidates": top3,
                "patched_preview": {
                    "descripcion_first_300": _section_preview(patched_entry, "descripcion"),
                    "nace_first_300": _section_preview(patched_entry, "nace"),
                },
                "top_v2_candidate_preview": {
                    "candidate_key": top_candidate_key,
                    "descripcion_first_300": _section_preview(v2_entry, "descripcion"),
                    "nace_first_300": _section_preview(v2_entry, "nace"),
                },
                "match_method_used": entry.get("match_method_used", ""),
                "confidence": rec["confidence"],
                "recommended_action": rec["recommended_action"],
                "recommendation_reason": rec["reason"],
            }
        )

    output = {
        "source_files": {
            "unresolved_review": str(UNRESOLVED_PATH.relative_to(ROOT)),
            "v2_corpus": str(V2_PATH.relative_to(ROOT)),
            "patched_corpus": str(PATCHED_PATH.relative_to(ROOT)),
            "compat_map": str(COMPAT_PATH.relative_to(ROOT)),
        },
        "summary": {
            "total_ogbe_unresolved": len(packet_entries),
            "safe_compat_suggestions": counts["ADD_TO_COMPAT_MAP"],
            "manual_import_needed_count": counts["MANUAL_CONTENT_IMPORT_NEEDED"],
            "leave_unmapped_count": counts["LEAVE_UNMAPPED"],
        },
        "entries": packet_entries,
    }

    OUT_JSON.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    md = [
        "# Odù v2 OGBE Manual Compatibility/Import Packet",
        "",
        "## Summary",
        f"- total OGBE unresolved: **{len(packet_entries)}**",
        f"- safe compat suggestions: **{counts['ADD_TO_COMPAT_MAP']}**",
        f"- manual import needed count: **{counts['MANUAL_CONTENT_IMPORT_NEEDED']}**",
        f"- leave unmapped count: **{counts['LEAVE_UNMAPPED']}**",
        "",
    ]

    for e in packet_entries:
        md.extend([
            f"## `{e['old_key']}`",
            f"- normalized form: `{e['normalized_form']}`",
            f"- family guess: `{e['family_guess']}`",
            f"- current existence in patched corpus: `{str(e['exists_in_patched_corpus']).lower()}`",
            f"- confidence: `{e['confidence']}`",
            f"- recommended action: `{e['recommended_action']}`",
            f"- match method used: `{e['match_method_used']}`",
            f"- recommendation reason: `{e['recommendation_reason']}`",
            "- top 3 nearest v2 candidates:",
        ])
        top3 = e["top_3_nearest_v2_candidates"]
        if top3:
            for c in top3:
                md.append(
                    f"  - `{c.get('key', '')}` ({c.get('method', '')}, score={c.get('score', '')})"
                )
        else:
            md.append("  - (none)")
        md.extend([
            "- patched preview:",
            f"  - descripcion: `{e['patched_preview']['descripcion_first_300']}`",
            f"  - nace: `{e['patched_preview']['nace_first_300']}`",
            "- top v2 candidate preview:",
            f"  - key: `{e['top_v2_candidate_preview']['candidate_key']}`",
            f"  - descripcion: `{e['top_v2_candidate_preview']['descripcion_first_300']}`",
            f"  - nace: `{e['top_v2_candidate_preview']['nace_first_300']}`",
            "",
        ])

    OUT_MD.write_text("\n".join(md), encoding="utf-8")

    print("[ogbe-packet] total_ogbe_unresolved=", len(packet_entries))
    print("[ogbe-packet] safe_compat_suggestions=", counts["ADD_TO_COMPAT_MAP"])
    print("[ogbe-packet] manual_import_needed_count=", counts["MANUAL_CONTENT_IMPORT_NEEDED"])
    print("[ogbe-packet] leave_unmapped_count=", counts["LEAVE_UNMAPPED"])
    print("[ogbe-packet] md=", OUT_MD)
    print("[ogbe-packet] json=", OUT_JSON)


if __name__ == "__main__":
    main()
