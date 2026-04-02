#!/usr/bin/env python3
import json
import re
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / 'lib' / 'main.dart'
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'odu_content.json'

text = SRC.read_text(encoding='utf-8')


def _skip_ws(s, i):
    n = len(s)
    while i < n and s[i].isspace():
        i += 1
    return i


def _parse_string(s, i):
    if s.startswith("'''", i):
        i += 3
        end = s.find("'''", i)
        if end == -1:
            raise ValueError('Unterminated triple-quote string')
        return s[i:end], end + 3
    if s[i] in ("'", '"'):
        quote = s[i]
        i += 1
        out = []
        n = len(s)
        while i < n:
            ch = s[i]
            if ch == '\\':
                if i + 1 < n:
                    out.append(s[i + 1])
                    i += 2
                    continue
            if ch == quote:
                return ''.join(out), i + 1
            out.append(ch)
            i += 1
        raise ValueError('Unterminated string')
    raise ValueError('Expected string at index %d' % i)


def _parse_identifier(s, i):
    n = len(s)
    start = i
    while i < n and (s[i].isalnum() or s[i] == '_'):
        i += 1
    if start == i:
        raise ValueError('Expected identifier at index %d' % i)
    return s[start:i], i


def _parse_string_list(s, i):
    items = []
    n = len(s)
    i = _skip_ws(s, i)
    while i < n:
        i = _skip_ws(s, i)
        if i < n and s[i] == ']':
            return items, i + 1
        value, i = _parse_string(s, i)
        items.append(value)
        i = _skip_ws(s, i)
        if i < n and s[i] == ',':
            i += 1
            continue
        if i < n and s[i] == ']':
            return items, i + 1
    raise ValueError('Unterminated list')


def _parse_string_map(s, i):
    items = {}
    n = len(s)
    i = _skip_ws(s, i)
    while i < n:
        i = _skip_ws(s, i)
        if i < n and s[i] == '}':
            return items, i + 1
        key, i = _parse_string(s, i)
        i = _skip_ws(s, i)
        if s[i] != ':':
            raise ValueError('Expected : after map key')
        i += 1
        i = _skip_ws(s, i)
        value, i = _parse_string(s, i)
        items[key] = value
        i = _skip_ws(s, i)
        if i < n and s[i] == ',':
            i += 1
            continue
        if i < n and s[i] == '}':
            return items, i + 1
    raise ValueError('Unterminated map')


def _parse_identifier_map(s, i):
    items = {}
    n = len(s)
    i = _skip_ws(s, i)
    while i < n:
        i = _skip_ws(s, i)
        if i < n and s[i] == '}':
            return items, i + 1
        key, i = _parse_string(s, i)
        i = _skip_ws(s, i)
        if s[i] != ':':
            raise ValueError('Expected : after map key')
        i += 1
        i = _skip_ws(s, i)
        ident, i = _parse_identifier(s, i)
        items[key] = ident
        i = _skip_ws(s, i)
        if i < n and s[i] == ',':
            i += 1
            continue
        if i < n and s[i] == '}':
            return items, i + 1
    raise ValueError('Unterminated identifier map')


def _parse_named_args(s):
    fields = {}
    i = 0
    n = len(s)
    while i < n:
        i = _skip_ws(s, i)
        if i >= n:
            break
        if s[i] == ')':
            break
        try:
            key, i = _parse_identifier(s, i)
        except ValueError:
            break
        i = _skip_ws(s, i)
        if i >= n or s[i] != ':':
            break
        i += 1
        i = _skip_ws(s, i)
        if i >= n:
            break
        if s[i] in ("'", '"') or s.startswith("'''", i):
            value, i = _parse_string(s, i)
            fields[key] = value
        else:
            # Skip non-string values
            while i < n and s[i] not in ',\n':
                i += 1
        i = _skip_ws(s, i)
        if i < n and s[i] == ',':
            i += 1
            continue
    return fields


# Parse patakies lists
patakies_lists = {}
for m in re.finditer(r"const\s+(_[A-Za-z0-9_]+)\s*=\s*<String>\[", text):
    name = m.group(1)
    start = m.end()
    items, _ = _parse_string_list(text, start)
    patakies_lists[name] = items

# Parse patakies content maps
patakies_content_maps = {}
for m in re.finditer(r"const\s+(_[A-Za-z0-9_]+)\s*=\s*<String, String>\{", text):
    name = m.group(1)
    start = m.end()
    items, _ = _parse_string_map(text, start)
    patakies_content_maps[name] = items

# Parse patakies index maps
patakies_index = {}
patakies_content_index = {}
index_marker = "const _patakiesByOduName = <String, List<String>>{" 
idx = text.find(index_marker)
if idx != -1:
    start = idx + len(index_marker)
    patakies_index, _ = _parse_identifier_map(text, start)

content_index_marker = "const _patakiesContentByOduName = <String, Map<String, String>>{" 
idx = text.find(content_index_marker)
if idx != -1:
    start = idx + len(content_index_marker)
    patakies_content_index, _ = _parse_identifier_map(text, start)

# Parse OduContent map
odu_marker = "const _oduContentByName = <String, OduContent>{"
idx = text.find(odu_marker)
if idx == -1:
    raise SystemExit('Odu content map not found')

start = idx + len(odu_marker)

odu_contents = {}
pos = start
while True:
    m = re.search(r"'([^']+)'\s*:\s*OduContent\(", text[pos:])
    if not m:
        break
    key = m.group(1)
    odu_start = pos + m.end()
    depth = 1
    i = odu_start
    n = len(text)
    while i < n and depth > 0:
        if text.startswith("'''", i):
            _, i = _parse_string(text, i)
            continue
        ch = text[i]
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        i += 1
    content_block = text[odu_start:i-1]
    fields = _parse_named_args(content_block)
    odu_contents[key] = fields
    pos = i

# Build combined data
all_keys = set()
all_keys.update(odu_contents.keys())
all_keys.update(patakies_index.keys())
all_keys.update(patakies_content_index.keys())

odu_data = {}
for key in sorted(all_keys):
    content = odu_contents.get(key, {})
    patakies_var = patakies_index.get(key)
    patakies = patakies_lists.get(patakies_var, []) if patakies_var else []
    patakies_content_var = patakies_content_index.get(key)
    patakies_content = (
        patakies_content_maps.get(patakies_content_var, {})
        if patakies_content_var
        else {}
    )
    odu_data[key] = {
        'content': content,
        'patakies': patakies,
        'patakiesContent': patakies_content,
    }

payload = {
    'version': 1,
    'odu': odu_data,
}

OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Wrote {OUT} with {len(odu_data)} entries')
