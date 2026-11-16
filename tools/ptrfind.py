"""Find pointer tables that point at the starts of 0-terminated strings in a text block.
A 'string start' is the block start or any offset right after a 0x00 byte."""
def string_starts(data, a, b):
    s = {a}
    for i in range(a, b):
        if data[i] == 0: s.add(i + 1)
    return s

def find_tables(data, a, b, cpu_base_of, search_ranges, min_run=4):
    """cpu_base_of(off) -> CPU address of file offset off. Returns list of
    (table_off, count, [target offsets])."""
    starts = string_starts(data, a, b)
    cpu2off = {cpu_base_of(o): o for o in starts}
    found = []
    for (sa, sb) in search_ranges:
        i = sa
        while i < sb - 1:
            run = []; j = i
            while j < sb - 1:
                w = data[j] | data[j+1] << 8
                if w in cpu2off: run.append(cpu2off[w]); j += 2
                else: break
            if len(run) >= min_run:
                found.append((i, len(run), run)); i = j
            else:
                i += 1
    return found
