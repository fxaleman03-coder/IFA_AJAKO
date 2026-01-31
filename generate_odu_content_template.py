import json
import re
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parent
    src = root / "lib" / "odu_data.dart"
    out = root / "assets" / "odu_content_template.json"

    text = src.read_text()
    names = re.findall(r'OduEntry\(name:\s*"([^"]+)"', text)
    seen = set()
    ordered = []
    for name in names:
        if name not in seen:
            seen.add(name)
            ordered.append(name)

    items = [
        {
            "name": name,
            "rezoYoruba": "",
            "suyereYoruba": "",
            "suyereEspanol": "",
            "nace": "",
            "descripcion": "",
            "ewes": "",
            "rezosYSuyeres": "",
            "obrasYEbbo": "",
            "refranes": "",
            "historiasYPatakies": "",
        }
        for name in ordered
    ]

    out.write_text(json.dumps(items, ensure_ascii=False, indent=2))
    print(f"Wrote {out} with {len(items)} entries")


if __name__ == "__main__":
    main()
