#!/usr/bin/env python3
import json
import re
from pathlib import Path
from typing import Dict, List

ROOT = Path(__file__).resolve().parents[1]
PATCHED_JSON = ROOT / "assets/odu_content_patched.json"
MAIN_DART = ROOT / "lib/main.dart"

OUT_MD = ROOT / "build/baba_ejiogbe_fix3_report.md"
OUT_JSON = ROOT / "build/baba_ejiogbe_fix3_summary.json"

TARGET_KEY = "BABA OGBE"


def _preview(text: str, n: int = 300) -> str:
    return (text or "")[:n]


def _split_blocks(text: str) -> List[str]:
    if not text.strip():
        return []
    parts = re.split(r"\n\s*\n", text.strip())
    return [p.strip() for p in parts if p.strip()]


def _has_exact_duplicate_block(text: str) -> bool:
    blocks = _split_blocks(text)
    if not blocks:
        return False
    return len(blocks) != len(set(blocks))


def _count_anchor(text: str, anchor: str) -> int:
    return text.upper().count(anchor.upper())


def _main_contains(pattern: str) -> bool:
    text = MAIN_DART.read_text(encoding="utf-8")
    return pattern in text


def main() -> None:
    data = json.loads(PATCHED_JSON.read_text(encoding="utf-8"))
    odu = data.get("odu", {})
    if TARGET_KEY not in odu:
        raise RuntimeError(f"Missing target key: {TARGET_KEY}")

    content = odu[TARGET_KEY].get("content", {})
    if not isinstance(content, dict):
        raise RuntimeError("Invalid content object for target.")

    rezo = content.get("rezoYoruba", "") if isinstance(content.get("rezoYoruba", ""), str) else ""
    suyere = content.get("suyereYoruba", "") if isinstance(content.get("suyereYoruba", ""), str) else ""
    prohibiciones = content.get("prohibiciones", "") if isinstance(content.get("prohibiciones", ""), str) else ""
    recomendaciones = content.get("recomendaciones", "") if isinstance(content.get("recomendaciones", ""), str) else ""
    rezos_grouped = content.get("rezosYSuyeres", "") if isinstance(content.get("rezosYSuyeres", ""), str) else ""

    rezo_dup_content = _has_exact_duplicate_block(rezo) or _count_anchor(
        rezo, "BABA EJIOGBE ALALEKUN"
    ) > 1
    suyere_dup_content = _has_exact_duplicate_block(suyere) or _count_anchor(
        suyere, "ASHINIMA ASHINIMA"
    ) > 2

    # UI checks by source presence (section builder).
    has_prohibiciones_ui = _main_contains("content.prohibiciones") and _main_contains(
        "strings.prohibicionesSigno"
    )
    has_recomendaciones_ui = _main_contains("content.recomendaciones") and _main_contains(
        "strings.recomendacionesSigno"
    )
    has_predicciones_ui = _main_contains("content.predicciones") and _main_contains(
        "strings.prediccionesSigno"
    )

    grouped_guard_present = _main_contains("showGroupedRezosOnly") and _main_contains(
        "!hasStandaloneRezo && !hasStandaloneSuyere"
    )

    # Duplication source determination for this issue.
    if rezo_dup_content:
        rezo_dup_source = "CONTENT"
    elif rezos_grouped.strip():
        rezo_dup_source = "UI"
    else:
        rezo_dup_source = "NONE"

    if suyere_dup_content:
        suyere_dup_source = "CONTENT"
    elif rezos_grouped.strip():
        suyere_dup_source = "UI"
    else:
        suyere_dup_source = "NONE"

    fixes_applied = [
        "Added dedicated UI sections for predicciones/prohibiciones/recomendaciones",
        "Disabled grouped 'Rezos y Suyeres' accordion when standalone rezo/suyere are present",
    ]

    summary = {
        "target_odu_key": TARGET_KEY,
        "content_audit": {
            "rezoYoruba": {"length": len(rezo), "first_300": _preview(rezo)},
            "suyereYoruba": {"length": len(suyere), "first_300": _preview(suyere)},
            "prohibiciones": {"length": len(prohibiciones), "first_300": _preview(prohibiciones)},
            "recomendaciones": {"length": len(recomendaciones), "first_300": _preview(recomendaciones)},
            "rezo_duplicate_in_content": rezo_dup_content,
            "suyere_duplicate_in_content": suyere_dup_content,
        },
        "ui_audit": {
            "prohibiciones_rendered": has_prohibiciones_ui,
            "recomendaciones_rendered": has_recomendaciones_ui,
            "predicciones_rendered": has_predicciones_ui,
            "grouped_rezos_guard_present": grouped_guard_present,
        },
        "result": {
            "rezo_duplication_source": rezo_dup_source,
            "suyere_duplication_source": suyere_dup_source,
            "fixes_applied": fixes_applied,
            "rezo_duplication_fixed": not rezo_dup_content and grouped_guard_present,
            "suyere_duplication_fixed": not suyere_dup_content and grouped_guard_present,
            "prohibiciones_visible": has_prohibiciones_ui and len(prohibiciones.strip()) > 0,
            "recomendaciones_visible": has_recomendaciones_ui and len(recomendaciones.strip()) > 0,
        },
    }

    OUT_JSON.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Baba Ejiogbe Fix3 Report",
        "",
        f"- target odu key: `{TARGET_KEY}`",
        "",
        "## Content Audit",
        f"- rezoYoruba: len={len(rezo)} preview=`{_preview(rezo)}`",
        f"- suyereYoruba: len={len(suyere)} preview=`{_preview(suyere)}`",
        f"- prohibiciones: len={len(prohibiciones)} preview=`{_preview(prohibiciones)}`",
        f"- recomendaciones: len={len(recomendaciones)} preview=`{_preview(recomendaciones)}`",
        f"- rezo duplicate in content: `{str(rezo_dup_content).lower()}`",
        f"- suyere duplicate in content: `{str(suyere_dup_content).lower()}`",
        "",
        "## UI Audit",
        f"- prohibiciones rendered: `{str(has_prohibiciones_ui).lower()}`",
        f"- recomendaciones rendered: `{str(has_recomendaciones_ui).lower()}`",
        f"- predicciones rendered: `{str(has_predicciones_ui).lower()}`",
        f"- grouped rezos guard present: `{str(grouped_guard_present).lower()}`",
        "",
        "## Summary",
        f"- rezo duplication source: `{rezo_dup_source}`",
        f"- suyere duplication source: `{suyere_dup_source}`",
        f"- prohibiciones rendered: `{'YES' if has_prohibiciones_ui else 'NO'}`",
        f"- recomendaciones rendered: `{'YES' if has_recomendaciones_ui else 'NO'}`",
        "- fixes applied:",
    ]
    for fix in fixes_applied:
        lines.append(f"  - {fix}")
    lines.append("")

    OUT_MD.write_text("\n".join(lines), encoding="utf-8")

    print("rezo duplication fixed =", "YES" if summary["result"]["rezo_duplication_fixed"] else "NO")
    print("suyere duplication fixed =", "YES" if summary["result"]["suyere_duplication_fixed"] else "NO")
    print("prohibiciones visible =", "YES" if summary["result"]["prohibiciones_visible"] else "NO")
    print("recomendaciones visible =", "YES" if summary["result"]["recomendaciones_visible"] else "NO")


if __name__ == "__main__":
    main()
