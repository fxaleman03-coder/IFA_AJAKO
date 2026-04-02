#!/usr/bin/env python3
import json
import re
import unicodedata
from pathlib import Path
from typing import Dict, List, Tuple

ROOT = Path(__file__).resolve().parents[1]

INPUT_PACKET = ROOT / "build/odu_v2_ogbe_manual_packet.json"
PATCHED_PATH = ROOT / "assets/odu_content_patched.json"
V2_PATH = ROOT / "assets/odu_content_v2_ready.json"
COMPAT_MAP_PATH = ROOT / "assets/odu_key_compat_map.json"

OUT_MD = ROOT / "build/odu_v2_ogbe_manual_import_packet.md"
OUT_JSON = ROOT / "build/odu_v2_ogbe_manual_import_packet.json"

SECTIONS = ["descripcion", "nace", "diceIfa", "obras", "eshu"]


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def normalize_key(text: str) -> str:
    text = (text or "").upper().strip()
    text = "".join(
        c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn"
    )
    text = text.replace("_", " ").replace("-", " ")
    text = re.sub(r"[^A-Z0-9 ]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def preview(text: str, size: int = 600) -> str:
    text = (text or "").strip()
    return text[:size]


def section_texts(entry: dict, sections: List[str]) -> Dict[str, str]:
    content = entry.get("content") if isinstance(entry, dict) else None
    if not isinstance(content, dict):
        return {s: "" for s in sections}
    out = {}
    for s in sections:
        v = content.get(s)
        out[s] = v if isinstance(v, str) else ""
    return out


def non_empty_count(texts: Dict[str, str]) -> int:
    return sum(1 for v in texts.values() if v.strip())


def family_guess_from_key(key: str) -> str:
    tokens = normalize_key(key).split()
    if len(tokens) >= 2:
        return f"{tokens[0]}-{tokens[1]}"
    if tokens:
        return tokens[0]
    return "UNKNOWN"


def choose_action(
    old_key: str,
    top_candidate: str,
    top_score: int,
    patched_texts: Dict[str, str],
    v2_texts: Dict[str, str],
) -> Tuple[str, str, str]:
    patched_non_empty = non_empty_count(patched_texts)
    v2_non_empty = non_empty_count(v2_texts)

    # Strong key proximity and candidate already rich enough => alias can work.
    if top_score >= 95 and v2_non_empty >= 3:
        return (
            "SAFE_TO_ALIAS_AFTER_REVIEW",
            "existing_v2_candidate_is_already_content_rich",
            "existing_v2_key",
        )

    # Candidate is clearly canonical but lacks content: merge old content into existing v2 key.
    if top_score >= 85 and patched_non_empty >= 2 and v2_non_empty <= 2:
        return (
            "MANUAL_MERGE_INTO_EXISTING_V2",
            "legacy_entry_has_substantial_content_while_v2_candidate_is_sparse",
            "existing_v2_key",
        )

    # Ambiguous proximity or unclear target => safer as new manual import bucket.
    return (
        "MANUAL_IMPORT_AS_NEW_ENTRY",
        "target_canonical_alignment_not_strong_enough_for_direct_merge_or_alias",
        "new_canonical_candidate",
    )


def main() -> None:
    packet = load_json(INPUT_PACKET)
    patched = load_json(PATCHED_PATH)
    v2 = load_json(V2_PATH)
    compat_map = load_json(COMPAT_MAP_PATH)

    packet_entries = packet.get("entries", []) if isinstance(packet, dict) else []
    manual_items = [
        e
        for e in packet_entries
        if isinstance(e, dict) and e.get("recommended_action") == "MANUAL_CONTENT_IMPORT_NEEDED"
    ]

    if len(manual_items) != 1:
        raise RuntimeError(
            f"Expected exactly 1 MANUAL_CONTENT_IMPORT_NEEDED item, found {len(manual_items)}."
        )

    item = manual_items[0]
    old_key = str(item.get("old_key", "")).strip()
    normalized = str(item.get("normalized_form", "")).strip()
    family_guess = str(item.get("family_guess", "")).strip()

    patched_odu = patched.get("odu", {}) if isinstance(patched, dict) else {}
    v2_odu = v2.get("odu", {}) if isinstance(v2, dict) else {}
    if not isinstance(patched_odu, dict) or not isinstance(v2_odu, dict):
        raise RuntimeError("Invalid corpus schema.")

    patched_entry = patched_odu.get(old_key, {})
    patched_texts = section_texts(patched_entry, SECTIONS)

    nearest_candidates = item.get("top_3_nearest_v2_candidates", [])
    nearest_candidates = [c for c in nearest_candidates if isinstance(c, dict)][:3]
    top_candidate = nearest_candidates[0].get("key", "") if nearest_candidates else ""
    top_score = int(nearest_candidates[0].get("score", 0)) if nearest_candidates else 0

    top_v2_entry = v2_odu.get(top_candidate, {}) if top_candidate else {}
    top_v2_texts = section_texts(top_v2_entry, SECTIONS)

    recommended_action, reason, target_type = choose_action(
        old_key=old_key,
        top_candidate=top_candidate,
        top_score=top_score,
        patched_texts=patched_texts,
        v2_texts=top_v2_texts,
    )

    payload = {
        "source_files": {
            "ogbe_packet": str(INPUT_PACKET.relative_to(ROOT)),
            "patched_corpus": str(PATCHED_PATH.relative_to(ROOT)),
            "v2_corpus": str(V2_PATH.relative_to(ROOT)),
            "compat_map": str(COMPAT_MAP_PATH.relative_to(ROOT)),
        },
        "target_item": {
            "old_key": old_key,
            "normalized_form": normalized,
            "family_guess": family_guess or family_guess_from_key(old_key),
            "exists_in_patched_corpus": old_key in patched_odu,
            "already_in_compat_map": old_key in compat_map,
            "nearest_v2_candidates": nearest_candidates,
            "patched_source_previews_first_600": {
                "descripcion": preview(patched_texts["descripcion"], 600),
                "nace": preview(patched_texts["nace"], 600),
                "diceIfa": preview(patched_texts["diceIfa"], 600),
                "obras": preview(patched_texts["obras"], 600),
                "eshu": preview(patched_texts["eshu"], 600),
            },
            "top_v2_candidate_previews_first_600": {
                "candidate_key": top_candidate,
                "descripcion": preview(top_v2_texts["descripcion"], 600),
                "nace": preview(top_v2_texts["nace"], 600),
                "diceIfa": preview(top_v2_texts["diceIfa"], 600),
                "obras": preview(top_v2_texts["obras"], 600),
                "eshu": preview(top_v2_texts["eshu"], 600),
            },
            "decision_analysis": {
                "should_be_new_canonical_entry_in_v2": target_type == "new_canonical_candidate",
                "should_be_compat_alias_to_existing_v2_key": target_type == "existing_v2_key",
                "patched_non_empty_section_count": non_empty_count(patched_texts),
                "top_candidate_non_empty_section_count": non_empty_count(top_v2_texts),
                "top_candidate_score": top_score,
            },
            "recommended_action": recommended_action,
            "recommendation_reason": reason,
            "likely_target_canonical_family": family_guess_from_key(top_candidate),
        },
    }

    OUT_JSON.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    t = payload["target_item"]
    lines = [
        "# OGBE Manual Import Packet (Single Unresolved Item)",
        "",
        f"- old key: `{t['old_key']}`",
        f"- normalized form: `{t['normalized_form']}`",
        f"- family guess: `{t['family_guess']}`",
        f"- exists in patched corpus: `{str(t['exists_in_patched_corpus']).lower()}`",
        f"- already in compat map: `{str(t['already_in_compat_map']).lower()}`",
        "",
        "## Full Patched Source Previews (first 600 chars)",
        f"- descripcion: `{t['patched_source_previews_first_600']['descripcion']}`",
        f"- nace: `{t['patched_source_previews_first_600']['nace']}`",
        f"- diceIfa: `{t['patched_source_previews_first_600']['diceIfa']}`",
        f"- obras: `{t['patched_source_previews_first_600']['obras']}`",
        f"- eshu: `{t['patched_source_previews_first_600']['eshu']}`",
        "",
        "## Nearest v2 candidate(s)",
    ]
    for c in t["nearest_v2_candidates"]:
        lines.append(
            f"- `{c.get('key','')}` ({c.get('method','')}, score={c.get('score','')})"
        )
    lines.extend(
        [
            "",
            "## Top v2 Candidate Previews (first 600 chars)",
            f"- key: `{t['top_v2_candidate_previews_first_600']['candidate_key']}`",
            f"- descripcion: `{t['top_v2_candidate_previews_first_600']['descripcion']}`",
            f"- nace: `{t['top_v2_candidate_previews_first_600']['nace']}`",
            f"- diceIfa: `{t['top_v2_candidate_previews_first_600']['diceIfa']}`",
            f"- obras: `{t['top_v2_candidate_previews_first_600']['obras']}`",
            f"- eshu: `{t['top_v2_candidate_previews_first_600']['eshu']}`",
            "",
            "## Resolution Assessment",
            f"- should be new canonical entry in v2: `{str(t['decision_analysis']['should_be_new_canonical_entry_in_v2']).lower()}`",
            f"- should be compat alias to existing v2 key: `{str(t['decision_analysis']['should_be_compat_alias_to_existing_v2_key']).lower()}`",
            f"- patched non-empty section count: `{t['decision_analysis']['patched_non_empty_section_count']}`",
            f"- top candidate non-empty section count: `{t['decision_analysis']['top_candidate_non_empty_section_count']}`",
            f"- top candidate score: `{t['decision_analysis']['top_candidate_score']}`",
            "",
            "## Recommendation",
            f"- recommended action: `{t['recommended_action']}`",
            f"- reason: `{t['recommendation_reason']}`",
            f"- likely target canonical family: `{t['likely_target_canonical_family']}`",
            "",
        ]
    )
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")

    print("[ogbe-manual-import] target_old_key=", t["old_key"])
    print("[ogbe-manual-import] recommended_action=", t["recommended_action"])
    print(
        "[ogbe-manual-import] likely_target_canonical_family=",
        t["likely_target_canonical_family"],
    )
    print("[ogbe-manual-import] md=", OUT_MD)
    print("[ogbe-manual-import] json=", OUT_JSON)


if __name__ == "__main__":
    main()
