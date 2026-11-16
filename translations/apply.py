"""Apply a translation dict {id: en} to a script JSON file.
usage (from python): apply('script/ff1/items.json', {1: 'Lute', ...})"""
import json
def apply(path, mapping):
    rows = json.load(open(path))
    for e in rows:
        if e['id'] in mapping:
            e['en'] = mapping[e['id']]
    json.dump(rows, open(path, 'w'), ensure_ascii=False, indent=1)
