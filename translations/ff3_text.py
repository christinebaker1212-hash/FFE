"""Apply FF3 dialogue translations kept as plain text.

translations/ff3/<table>.txt holds blocks:
    @@ <id>
    <translation, real line breaks, exactly as it should be stored>
The block text runs up to the line before the next '@@'. A translation that ends in
a line break is written with an empty last line.
usage: ff3_text.py            (applies every translations/ff3/*.txt to script/ff3/<table>.json)"""
import glob, json, os, re

def parse(path):
    src = open(path, encoding='utf-8').read()
    if src.endswith('\n'): src = src[:-1]
    out = {}
    for m in re.finditer(r'^@@ (\d+)\n(.*?)(?=\n@@ \d+\n|\Z)', src, re.S | re.M):
        out[int(m.group(1))] = m.group(2)
    return out

if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    for path in sorted(glob.glob(os.path.join(here, 'ff3', '*.txt'))):
        table = os.path.splitext(os.path.basename(path))[0]
        js = os.path.join(here, '..', 'script', 'ff3', table + '.json')
        tr = parse(path); rows = json.load(open(js))
        for e in rows:
            if e['id'] in tr: e['en'] = tr[e['id']]
        json.dump(rows, open(js, 'w'), ensure_ascii=False, indent=1)
        print(table, len(tr))
