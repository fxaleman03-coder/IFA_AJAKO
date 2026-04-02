#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMG = ROOT / "IMG"
JSON_PATH = ROOT / "assets" / "odu_content.json"


def _strip_accents(text: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn"
    )


def _pdf_text(path: Path) -> str:
    raw = subprocess.check_output(
        ["pdftotext", "-layout", str(path), "-"],
        stderr=subprocess.DEVNULL,
    )
    text = raw.decode("utf-8", errors="ignore")
    # Normalize common glue errors like "FURIBUYEMAREZO:"
    text = re.sub(r"(?<!\n)REZO:", r"\nREZO:", text)
    text = re.sub(r"(?<!\n)SUYERE:", r"\nSUYERE:", text)
    return text.replace("\x0c", "\n")


def _clean_lines(text: str) -> list[str]:
    lines = [line.rstrip() for line in text.splitlines()]
    cleaned: list[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            cleaned.append("")
            continue
        # Drop standalone page numbers
        if re.fullmatch(r"\d+", stripped):
            continue
        cleaned.append(line)
    return cleaned


def _collapse_blank_lines(text: str) -> str:
    lines = [line.rstrip() for line in text.splitlines()]
    out: list[str] = []
    blank = False
    for line in lines:
        if not line.strip():
            if blank:
                continue
            blank = True
            out.append("")
            continue
        blank = False
        out.append(line)
    return "\n".join(out).strip()


def _detect_heading(line: str) -> str | None:
    raw = line.strip()
    if not raw:
        return None
    # Remove bullets
    raw = raw.lstrip("•").strip()
    upper = _strip_accents(raw).upper()
    upper = re.sub(r"[:.]+$", "", upper).strip()
    upper = re.sub(r"\s+", " ", upper)
    if upper.startswith("REZOS Y SUYERES"):
        return "rezosYSuyeres"
    if upper.startswith("REZO"):
        return "rezoYoruba"
    if upper.startswith("SUYERE"):
        return "suyereYoruba"
    if upper.startswith("EN ESTE SIGNO NACE") or upper.startswith("EN ESTE ODU NACE"):
        return "nace"
    if upper.startswith("DESCRIPCION DEL SIGNO") or upper.startswith(
        "DESCRIPCION DEL ODDUN"
    ) or upper.startswith("DESCRIPCION DEL ODU"):
        return "descripcion"
    if upper.startswith("EWE") or upper.startswith("EWES"):
        return "ewes"
    if upper.startswith("ESHU"):
        if " DE " in f" {upper} " or " DEL " in f" {upper} ":
            return "eshu"
        return None
    if upper.startswith("OBRAS"):
        return "obrasYEbbo"
    if upper.startswith("DICE IFA") or upper.startswith("DICE IFA"):
        return "diceIfa"
    if upper.startswith("REFRAN"):
        return "refranes"
    if upper.startswith("HISTORIA") or upper.startswith("HISTORIAS"):
        return "historiasYPatakies"
    if upper.startswith("PATAKI") or upper.startswith("PATAKIES"):
        return "historiasYPatakies"
    return None


def _parse_sections(text: str) -> dict[str, str]:
    lines = _clean_lines(text)
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in lines:
        head = _detect_heading(line)
        if head:
            if current == "rezosYSuyeres" and head in {"rezoYoruba", "suyereYoruba"}:
                sections.setdefault(current, []).append(line)
                continue
            current = head
            sections.setdefault(current, [])
            continue
        if current:
            sections.setdefault(current, []).append(line)
    cleaned: dict[str, str] = {}
    for key, block in sections.items():
        cleaned[key] = _collapse_blank_lines("\n".join(block))
    # Extract Spanish translation from suyere if lines start with "*"
    if "suyereYoruba" in cleaned:
        su_lines = cleaned["suyereYoruba"].splitlines()
        su_keep: list[str] = []
        es_lines: list[str] = []
        for line in su_lines:
            stripped = line.strip()
            if stripped.startswith("*"):
                es_lines.append(stripped.lstrip("*").strip())
            else:
                su_keep.append(line)
        cleaned["suyereYoruba"] = _collapse_blank_lines("\n".join(su_keep))
        if es_lines:
            cleaned["suyereEspanol"] = _collapse_blank_lines("\n".join(es_lines))
    return cleaned


def _normalize_title(title: str) -> str:
    title = title.strip()
    title = re.sub(r"\s+", " ", title)
    title = title.rstrip(".")
    return title


def _normalize_key(title: str) -> str:
    return re.sub(r"[^A-Z0-9 ]", "", _strip_accents(title).upper())


def _parse_patakies_list(text: str) -> list[str]:
    lines = _clean_lines(text)
    items: list[str] = []
    for line in lines:
        match = re.match(r"^\s*\d+[\.\)]\s+(.*)$", line)
        if not match:
            continue
        title = _normalize_title(match.group(1))
        if title:
            items.append(title)
    return items


def _parse_patakies_content(text: str) -> dict[str, str]:
    lines = _clean_lines(text)
    entries: dict[str, list[str]] = {}
    current: str | None = None
    for idx, line in enumerate(lines):
        match = re.match(r"^\s*\d+[\.\)]\s+(.*)$", line)
        if match:
            prev_line = lines[idx - 1] if idx > 0 else ""
            next_line = lines[idx + 1] if idx + 1 < len(lines) else ""
            prev_ok = (not prev_line.strip()) or ("PATAK" in prev_line.upper())
            next_is_numbered = re.match(r"^\s*\d+[\.\)]\s+", next_line) is not None
            if not prev_ok or next_is_numbered:
                if current:
                    entries[current].append(line)
                continue
            title = _normalize_title(match.group(1))
            current = title if title else None
            if current:
                entries.setdefault(current, [])
            continue
        if current:
            entries[current].append(line)
    result: dict[str, str] = {}
    for key, block in entries.items():
        result[key] = _collapse_blank_lines("\n".join(block))
    return result


def _merge_patakies(
    list_items: list[str], content_map: dict[str, str]
) -> tuple[list[str], dict[str, str]]:
    if not list_items:
        return list(content_map.keys()), content_map
    content_norm = {_normalize_key(k): k for k in content_map.keys()}
    ordered: list[str] = []
    merged: dict[str, str] = {}
    for title in list_items:
        key = _normalize_key(title)
        source_key = content_norm.get(key)
        if source_key:
            merged[title] = content_map.get(source_key, "")
        else:
            merged[title] = ""
        ordered.append(title)
    # Keep any extra content not in list
    for title, body in content_map.items():
        norm = _normalize_key(title)
        if norm not in {_normalize_key(t) for t in ordered}:
            ordered.append(title)
            merged[title] = body
    return ordered, merged


def _find_line_index(lines: list[str], marker: str) -> int:
    marker_upper = _strip_accents(marker).upper()
    for i, line in enumerate(lines):
        line_upper = _strip_accents(line).upper()
        if marker_upper in line_upper:
            return i
    return -1


def _join_lines(lines: list[str]) -> str:
    return _collapse_blank_lines("\n".join(lines))


def _number_items_from_bullets(text: str) -> str:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    items: list[str] = []
    current = ""
    for line in lines:
        is_numbered = re.match(r"^\d+[\.\)]\s+", line) is not None
        is_bullet = line.startswith("•")
        if is_numbered or is_bullet:
            if current:
                items.append(current.strip())
            current = re.sub(r"^(\d+[\.\)]\s+|•\s*)", "", line).strip()
        else:
            if not current:
                current = line
            else:
                current = f"{current} {line}"
    if current:
        items.append(current.strip())
    return "\n".join(f"{i + 1}. {item}" for i, item in enumerate(items))


def _number_items_from_commas(text: str) -> str:
    raw = text.replace("\n", " ")
    parts = [part.strip() for part in raw.split(",") if part.strip()]
    return "\n".join(f"{i + 1}. {part}" for i, part in enumerate(parts))


def _fix_baba_ogbe(data: dict) -> None:
    pdf_text = _pdf_text(IMG / "BABA EJIOGBE.pdf")
    lines = _clean_lines(pdf_text)
    idx_suyere = _find_line_index(lines, "SUYERE")
    idx_rezo_first = _find_line_index(lines, "REZO")
    idx_desc = _find_line_index(lines, "DESCRIPCION DEL SIGNO")
    idx_nace = _find_line_index(lines, "EN ESTE ODU NACE")
    idx_ewes = _find_line_index(lines, "EWE DEL SIGNO")
    idx_eshu = _find_line_index(lines, "ESHU DEL SIGNO")
    idx_rezos = _find_line_index(lines, "REZOS Y SUYERES")
    idx_obras = _find_line_index(lines, "OBRAS DE BABA EJIOGBE")
    idx_dice = _find_line_index(lines, "DICE IFA BABA EJIOGBE")
    idx_refranes = _find_line_index(lines, "REFRANES DE BABA EJIOGBE")
    idx_patakies = _find_line_index(lines, "PATAKIES DE BABA EJIOGBE")

    content_update: dict[str, str] = {}

    # Rezo Yoruba: first REZO block up to descripcion.
    if idx_rezo_first != -1 and idx_desc != -1 and idx_rezo_first < idx_desc:
        content_update["rezoYoruba"] = _join_lines(lines[idx_rezo_first:idx_desc])

    # Suyere Yoruba: collect all ASHINIMA lines (plus any other direct suyere lines).
    suyere_lines = []
    for line in lines:
        if "ASHINIMA ASHINIMA" in _strip_accents(line).upper():
            suyere_lines.append(line.strip())
    if suyere_lines:
        content_update["suyereYoruba"] = _join_lines(suyere_lines)

    # Descripcion: between descripcion and nace.
    if idx_desc != -1 and idx_nace != -1 and idx_desc < idx_nace:
        content_update["descripcion"] = _join_lines(lines[idx_desc + 1 : idx_nace])

    # Nace: from nace line up to ewes.
    if idx_nace != -1 and idx_ewes != -1 and idx_nace < idx_ewes:
        nace_block = _join_lines(lines[idx_nace:idx_ewes])
        numbered = _number_items_from_bullets(nace_block)
        cleaned_lines = []
        for line in numbered.splitlines():
          cleaned_lines.append(
              re.sub(
                  r"^(\d+\.\s+)EN ESTE (ODU|SIGNO) NACE\s+",
                  r"\1",
                  line,
                  flags=re.IGNORECASE,
              )
          )
        content_update["nace"] = "\\n".join(cleaned_lines).strip()

    # Ewes: between ewes and eshu.
    if idx_ewes != -1 and idx_eshu != -1 and idx_ewes < idx_eshu:
        ewes_block = _join_lines(lines[idx_ewes + 1 : idx_eshu])
        content_update["ewes"] = _number_items_from_commas(ewes_block)

    # Eshu: between eshu and rezos.
    eshu_block = ""
    removed_rezo_line = ""
    if idx_eshu != -1 and idx_rezos != -1 and idx_eshu < idx_rezos:
        eshu_lines = lines[idx_eshu + 1 : idx_rezos]
        filtered = []
        for line in eshu_lines:
            if _strip_accents(line).upper().startswith("REZO:"):
                removed_rezo_line = line.strip()
                continue
            filtered.append(line)
        eshu_block = _join_lines(filtered)
        content_update["eshu"] = eshu_block

    # Rezos y suyeres: between rezos and obras.
    if idx_rezos != -1 and idx_obras != -1 and idx_rezos < idx_obras:
        rezos_block = _join_lines(lines[idx_rezos + 1 : idx_obras])
        if removed_rezo_line and removed_rezo_line not in rezos_block:
            rezos_block = _join_lines([removed_rezo_line, "", rezos_block])
        content_update["rezosYSuyeres"] = rezos_block

    # Obras: between obras and dice.
    if idx_obras != -1 and idx_dice != -1 and idx_obras < idx_dice:
        obras_lines = lines[idx_obras + 1 : idx_dice]
        updated_obras: list[str] = []
        inserted = False
        for line in obras_lines:
            updated_obras.append(line)
            if (
                not inserted
                and _strip_accents(line).upper().startswith(
                    "SE CONFECCIONA UNA ATENA CON LA SIGUIENTE FORMA"
                )
            ):
                updated_obras.append("[[ATENA_BABA_EJIOGBE]]")
                inserted = True
        content_update["obrasYEbbo"] = _join_lines(updated_obras)

    # Dice Ifa: between dice and refranes.
    if idx_dice != -1 and idx_refranes != -1 and idx_dice < idx_refranes:
        content_update["diceIfa"] = _join_lines(lines[idx_dice + 1 : idx_refranes])

    # Refranes: between refranes and patakies.
    if idx_refranes != -1 and idx_patakies != -1 and idx_refranes < idx_patakies:
        content_update["refranes"] = _join_lines(
            lines[idx_refranes + 1 : idx_patakies]
        )

    # Apply updates to data
    if content_update:
        _update_entry(data, "BABA OGBE", content_update)


def _read_json() -> dict:
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("odu_content.json is not a dict")
    data.setdefault("odu", {})
    return data


def _write_json(data: dict) -> None:
    JSON_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def _update_entry(
    data: dict,
    key: str,
    content_update: dict[str, str],
    patakies: list[str] | None = None,
    patakies_content: dict[str, str] | None = None,
    clear_histories_if_patakies: bool = True,
) -> None:
    odu = data["odu"]
    entry = odu.get(key) if isinstance(odu, dict) else None
    if not isinstance(entry, dict):
        entry = {}
    content = entry.get("content")
    if not isinstance(content, dict):
        content = {}
    content.setdefault("name", key)
    for field, value in content_update.items():
        if value:
            content[field] = value
    entry["content"] = content
    if patakies is not None and patakies:
        entry["patakies"] = patakies
    if patakies_content is not None and patakies_content:
        entry["patakiesContent"] = patakies_content
    if clear_histories_if_patakies and patakies_content:
        entry["content"]["historiasYPatakies"] = ""
    odu[key] = entry
    data["odu"] = odu


def main() -> None:
    data = _read_json()

    targets = {
        "BABA OGBE": {
            "main_pdf": "BABA EJIOGBE.pdf",
            "patakies_pdf": "PATAKIES DE BABA EJIOGBE.pdf",
            "extra_obras_pdf": "OBRAS DE BABA EJIOGBE (FALTANTES) .pdf",
        },
        "OGBE YEKU": {
            "main_pdf": "OGBE OYEKUN.pdf",
            "patakies_pdf": "OGBE OYECUN PATAKIES.pdf",
        },
        "OGBE WEÑE": {
            "main_pdf": "OGBE IWORI.pdf",
            "patakies_pdf": "PATAKIES DE OGBE IWORI.pdf",
        },
        "OGBE DI": {
            "main_pdf": "OGBE ODI.pdf",
            "list_pdf": "LISTA DE PATAKIES DE OGBE ODI.pdf",
            "patakies_pdf": "PATAKIES DE OGBE ODI.pdf",
        },
        "OGBE ROSO": {
            "main_pdf": "OGBE IROSO.pdf",
            "list_pdf": "LISTA DE PATAKIES DE OGBE ROSO.pdf",
            "patakies_pdf": "PATAKIES DE OGBE IROSO.pdf",
        },
        "OGBE WANLE": {
            "main_pdf": "OGBE WANLE.pdf",
            "list_pdf": "LISTA DE PATAKIES DE OGBE WANLE.pdf",
            "patakies_pdf": "PATAKIES DE OGBE WANLE.pdf",
        },
        "OGBE BARA": {
            "main_pdf": "OGBE BARA.pdf",
            "list_pdf": "LISTA DE PATAKIES DE OGBE BARA.pdf",
            "patakies_pdf": "PATAKIES DE OGBE BARA.pdf",
        },
        "OGBE KANA": {
            "main_pdf": "OGBE KANA.pdf",
            "list_pdf": "LISTA DE PATAKIES DE OGBE KANA.pdf",
        },
    }

    for key, meta in targets.items():
        main_pdf = IMG / meta["main_pdf"]
        if not main_pdf.exists():
            print(f"Missing main PDF: {main_pdf}")
            continue
        sections = _parse_sections(_pdf_text(main_pdf))
        # Ensure all fields exist even if empty
        content_update = {
            "name": key,
            "rezoYoruba": sections.get("rezoYoruba", ""),
            "suyereYoruba": sections.get("suyereYoruba", ""),
            "suyereEspanol": sections.get("suyereEspanol", ""),
            "nace": sections.get("nace", ""),
            "descripcion": sections.get("descripcion", ""),
            "ewes": sections.get("ewes", ""),
            "eshu": sections.get("eshu", ""),
            "rezosYSuyeres": sections.get("rezosYSuyeres", ""),
            "obrasYEbbo": sections.get("obrasYEbbo", ""),
            "diceIfa": sections.get("diceIfa", ""),
            "refranes": sections.get("refranes", ""),
            "historiasYPatakies": sections.get("historiasYPatakies", ""),
        }

        # Patakies
        list_items: list[str] = []
        list_pdf = meta.get("list_pdf")
        if list_pdf:
            list_path = IMG / list_pdf
            if list_path.exists():
                list_items = _parse_patakies_list(_pdf_text(list_path))
        content_map: dict[str, str] = {}
        patakies_pdf = meta.get("patakies_pdf")
        if patakies_pdf:
            pat_path = IMG / patakies_pdf
            if pat_path.exists():
                content_map = _parse_patakies_content(_pdf_text(pat_path))
                if not list_items:
                    list_items = list(content_map.keys())

        patakies: list[str] = []
        patakies_content: dict[str, str] = {}
        if list_items or content_map:
            patakies, patakies_content = _merge_patakies(list_items, content_map)

        # Extra obras for BABA OGBE
        extra_obras = meta.get("extra_obras_pdf")
        if extra_obras:
            extra_path = IMG / extra_obras
            if extra_path.exists():
                extra_text = _collapse_blank_lines(_pdf_text(extra_path))
                if extra_text:
                    content_update["obrasYEbbo"] = (
                        content_update.get("obrasYEbbo", "").strip()
                        + ("\n\n" if content_update.get("obrasYEbbo") else "")
                        + extra_text
                    )

        _update_entry(
            data,
            key,
            content_update,
            patakies=patakies or None,
            patakies_content=patakies_content or None,
            clear_histories_if_patakies=True,
        )

    # Remove old mismatched OGBE keys if present
    for stale in ("OGBE OYEKU", "OGBE OYECU", "OGBE OYEKUN"):
        data.get("odu", {}).pop(stale, None)

    _fix_baba_ogbe(data)

    _write_json(data)
    print("Updated odu_content.json")


if __name__ == "__main__":
    main()
