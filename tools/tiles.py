"""Render a region of a ROM as NES 2bpp tiles (for locating/reading fonts)."""
import sys
from PIL import Image

def decode_tile(data, off):
    px = [[0]*8 for _ in range(8)]
    for y in range(8):
        lo, hi = data[off+y], data[off+y+8]
        for x in range(8):
            b = 7 - x
            px[y][x] = ((lo >> b) & 1) | (((hi >> b) & 1) << 1)
    return px

def decode_tile_1bpp(data, off):
    return [[((data[off+y] >> (7-x)) & 1) * 3 for x in range(8)] for y in range(8)]

def render(data, start, count, cols=16, scale=3, bpp=2, label=True):
    rows = (count + cols - 1) // cols
    tsz = 16 if bpp == 2 else 8
    img = Image.new('L', (cols*9*scale + (40 if label else 0), rows*9*scale), 40)
    pal = [0, 110, 180, 255]
    for i in range(count):
        t = (decode_tile if bpp == 2 else decode_tile_1bpp)(data, start + i*tsz)
        cx, cy = (i % cols)*9*scale + (40 if label else 0), (i // cols)*9*scale
        for y in range(8):
            for x in range(8):
                for sy in range(scale):
                    for sx in range(scale):
                        img.putpixel((cx+x*scale+sx, cy+y*scale+sy), pal[t[y][x]])
    if label:
        from PIL import ImageDraw
        d = ImageDraw.Draw(img)
        for r in range(rows):
            d.text((1, r*9*scale + 4), '%02X' % ((r*cols) & 0xFF), fill=255)
    return img

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()[16:]
    start = int(sys.argv[2], 16); count = int(sys.argv[3])
    bpp = int(sys.argv[5]) if len(sys.argv) > 5 else 2
    render(data, start, count, bpp=bpp).save(sys.argv[4])
