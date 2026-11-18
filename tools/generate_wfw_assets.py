#!/usr/bin/env python3
"""Generate original 16-colour WfW-style pixel icons.

These drawings are project originals assembled from primitive shapes. They do
not contain extracted Microsoft resources. Larger variants are deterministic
nearest-neighbour outputs so each logical pixel remains stable.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).parents[1] / "assets/wfw"
PAL = {
    "k": "#000000", "g": "#808080", "f": "#c0c0c0", "w": "#ffffff",
    "n": "#000080", "b": "#0000ff", "t": "#008080", "a": "#00ffff",
    "r": "#ff0000", "m": "#800000", "y": "#ffff00", "o": "#808000",
    "l": "#00ff00", "p": "#800080", "h": "#ff00ff"
}

def box(d, xy, fill="f", outline="k"):
    d.rectangle(xy, fill=PAL[fill], outline=PAL[outline])
    x1,y1,x2,y2=xy
    if x2-x1>3 and y2-y1>3:
        d.line((x1+1,y1+1,x2-1,y1+1), fill=PAL["w"])
        d.line((x1+1,y1+1,x1+1,y2-1), fill=PAL["w"])
        d.line((x1+1,y2-1,x2-1,y2-1), fill=PAL["g"])
        d.line((x2-1,y1+1,x2-1,y2-1), fill=PAL["g"])

def window(d, xy, title="n"):
    box(d,xy)
    x1,y1,x2,y2=xy
    d.rectangle((x1+2,y1+2,x2-2,min(y1+6,y2-2)),fill=PAL[title])
    if x2-x1>8: d.point((x2-4,y1+4),fill=PAL["w"])

def group(d):
    # Minimized Program Manager group: one tiny captioned window containing
    # the six coloured program glyphs visible in the WfW reference.
    window(d,(2,3,29,27))
    d.rectangle((4,10,27,25),fill=PAL["w"],outline=PAL["k"])
    for x,y,c in [(7,12,"b"),(15,12,"r"),(23,12,"t"),(7,20,"p"),(15,20,"l"),(23,20,"y")]:
        d.rectangle((x-2,y-2,x+2,y+2),fill=PAL["f"],outline=PAL["k"])
        d.point((x,y),fill=PAL[c])

def default(d):
    window(d,(3,3,28,28))
    d.rectangle((6,11,25,25),fill=PAL["w"])
    d.line((7,22,12,16,16,20,23,12),fill=PAL["b"],width=2)
    d.rectangle((20,13,22,15),fill=PAL["r"])

def file_manager(d):
    # Yellow filing cabinet silhouette used by the Program Manager Main group.
    d.rectangle((7,2,25,29),fill=PAL["y"],outline=PAL["k"])
    d.line((8,3,24,3),fill=PAL["w"])
    d.line((8,28,24,28),fill=PAL["o"])
    d.rectangle((10,5,22,10),fill=PAL["b"],outline=PAL["k"])
    for y in (13,20):
        d.rectangle((9,y,23,y+6),fill=PAL["y"],outline=PAL["k"])
        d.rectangle((14,y+2,19,y+3),fill=PAL["k"])

def control_panel(d):
    box(d,(3,4,28,27))
    for x,y,c in [(9,11,"b"),(20,11,"r"),(9,21,"l"),(20,21,"y")]:
        d.ellipse((x-3,y-3,x+3,y+3),fill=PAL[c],outline=PAL["k"])
        d.line((x-2,y,x+2,y),fill=PAL["w"])

def printer(d):
    d.rectangle((7,2,24,11),fill=PAL["w"],outline=PAL["k"])
    box(d,(3,9,28,23))
    d.rectangle((7,18,24,29),fill=PAL["w"],outline=PAL["k"])
    for y in (21,24,27): d.line((10,y,22,y),fill=PAL["n"])
    d.rectangle((23,12,25,14),fill=PAL["l"])

def clipboard(d):
    box(d,(6,4,26,29))
    d.rectangle((11,2,21,7),fill=PAL["o"],outline=PAL["k"])
    d.rectangle((9,9,23,26),fill=PAL["w"],outline=PAL["g"])
    for y in (12,16,20,24): d.line((11,y,21,y),fill=PAL["n"])

def dos(d):
    window(d,(2,5,30,27))
    d.rectangle((5,12,27,24),fill=PAL["k"])
    d.text((7,12),"C:\\",fill=PAL["w"],stroke_width=0)
    d.rectangle((20,20,24,21),fill=PAL["f"])

def setup(d):
    box(d,(2,3,29,28))
    for x,y,c in [(8,9,"r"),(16,9,"l"),(8,17,"b"),(16,17,"y")]: d.rectangle((x,y,x+6,y+6),fill=PAL[c],outline=PAL["k"])
    d.line((23,17,28,12),fill=PAL["k"],width=2)
    d.ellipse((20,17,25,22),outline=PAL["k"])

def document(d, badge="n"):
    d.polygon(((6,2),(21,2),(27,8),(27,30),(6,30)),fill=PAL["w"],outline=PAL["k"])
    d.line((21,2,21,8,27,8),fill=PAL["g"])
    for y in (12,16,20,24): d.line((9,y,23,y),fill=PAL["n"])
    d.rectangle((2,19,13,29),fill=PAL[badge],outline=PAL["k"])

def accessories(d):
    d.polygon(((4,25),(18,5),(23,9),(10,29)),fill=PAL["y"],outline=PAL["k"])
    d.ellipse((17,2,27,12),fill=PAL["b"],outline=PAL["k"])
    d.rectangle((3,23,10,30),fill=PAL["r"],outline=PAL["k"])

def network(d):
    for x,y in [(5,5),(21,5),(13,21)]: window(d,(x,y,x+8,y+7))
    d.line((9,13,17,21,25,13),fill=PAL["n"],width=2)
    d.line((9,13,25,13),fill=PAL["n"],width=2)

def games(d):
    d.polygon(((4,4),(21,2),(25,25),(8,28)),fill=PAL["w"],outline=PAL["k"])
    d.polygon(((10,7),(13,10),(10,13),(7,10)),fill=PAL["r"])
    d.ellipse((15,16,20,21),fill=PAL["b"])
    d.polygon(((16,5),(29,10),(22,29),(11,24)),outline=PAL["k"])

def startup(d):
    group(d)
    d.polygon(((4,20),(17,20),(17,15),(28,24),(17,31),(17,27),(4,27)),fill=PAL["l"],outline=PAL["k"])

def progman(d):
    window(d,(2,2,29,29))
    for xy,c in [((5,10,15,18),"b"),((17,10,26,18),"r"),((5,20,15,26),"l"),((17,20,26,26),"y")]:
        window(d,xy,c)

def warning(d):
    d.polygon(((16,2),(30,28),(2,28)),fill=PAL["y"],outline=PAL["k"])
    d.rectangle((15,9,17,20),fill=PAL["k"]); d.rectangle((15,23,17,25),fill=PAL["k"])

def information(d):
    d.ellipse((3,3,29,29),fill=PAL["b"],outline=PAL["k"])
    d.rectangle((15,13,17,24),fill=PAL["w"]); d.rectangle((15,8,17,10),fill=PAL["w"])

QUESTION_MARK=[
    "..#####..",
    ".#######.",
    "###...###",
    "###...###",
    "......###",
    ".....###.",
    "....###..",
    "...###...",
    "...###...",
    ".........",
    "...###...",
    "...###...",
]

def question(d):
    # White balloon with a bold blue question mark (drawn pixel by pixel: no font involved).
    d.ellipse((3,3,29,29),fill=PAL["w"],outline=PAL["k"])
    for y,row in enumerate(QUESTION_MARK):
        for x,ch in enumerate(row):
            if ch=="#": d.point((12+x,10+y),fill=PAL["b"])

def terminal(d):
    dos(d)

def calculator(d):
    box(d,(6,2,26,30)); d.rectangle((9,5,23,10),fill=PAL["w"],outline=PAL["k"])
    for y in (14,19,24):
        for x in (10,15,20): d.rectangle((x,y,x+2,y+2),fill=PAL["n"])

def clock(d):
    d.ellipse((3,3,29,29),fill=PAL["w"],outline=PAL["k"],width=2)
    d.line((16,16,16,7),fill=PAL["n"],width=2); d.line((16,16,23,20),fill=PAL["n"],width=2)

def paint(d): accessories(d)

def cardfile(d):
    for off in (0,3,6): d.rectangle((3+off,5-off,24+off,27-off),fill=PAL["w"],outline=PAL["k"])
    for y in (12,16,20): d.line((12,y,25,y),fill=PAL["b"])

def note(d):
    # Sticky note: a square of yellow paper pinned at the top, a few written lines and a
    # turned-up bottom-right corner, with the grey drop shadow the other paper icons use.
    d.polygon(((6,6),(29,6),(29,24),(23,30),(6,30)),fill=PAL["g"])
    d.polygon(((3,4),(26,4),(26,22),(20,28),(3,28)),fill=PAL["y"],outline=PAL["k"])
    d.line((4,5,25,5),fill=PAL["w"])
    d.line((4,5,4,27),fill=PAL["w"])
    d.polygon(((20,28),(20,22),(26,22)),fill=PAL["o"],outline=PAL["k"])
    for y,x2 in ((11,22),(15,22),(19,22),(23,16)): d.line((7,y,x2,y),fill=PAL["n"])
    d.ellipse((12,1,18,7),fill=PAL["r"],outline=PAL["k"])
    d.point((14,3),fill=PAL["w"])

def web(d):
    # Web site: a blue globe with green land, white meridian and equator lines and a highlight,
    # over a sheet of paper (the WfW document shape) so it still reads as "a page".
    d.polygon(((9,2),(24,2),(30,8),(30,30),(9,30)),fill=PAL["w"],outline=PAL["k"])
    d.line((24,2,24,8,30,8),fill=PAL["g"])
    d.ellipse((1,7,23,29),fill=PAL["b"],outline=PAL["k"])
    for poly in (((5,12),(10,10),(13,13),(11,17),(7,19),(4,16)),
                 ((14,19),(19,17),(21,21),(17,26),(14,24)),
                 ((15,10),(18,11),(17,13))):
        d.polygon(poly,fill=PAL["l"],outline=PAL["o"])
    d.arc((7,8,17,28),90,270,fill=PAL["a"])
    d.arc((7,8,17,28),270,90,fill=PAL["a"])
    d.line((2,18,22,18),fill=PAL["a"])
    d.point((6,11),fill=PAL["w"]); d.point((7,10),fill=PAL["w"])

ICONS={
 "group":group,"default":default,"file-manager":file_manager,"control-panel":control_panel,
 "print-manager":printer,"clipbook":clipboard,"dos":dos,"setup":setup,
 "pif":lambda d:document(d,"p"),"readme":lambda d:document(d,"t"),
 "accessories":accessories,"network":network,"games":games,"startup":startup,
 "program-manager":progman,"warning":warning,"information":information,"question":question,
 "terminal":terminal,"calculator":calculator,"clock":clock,"paint":paint,"cardfile":cardfile,
 "note":note,"web":web
}

# `generate_wfw_assets.py note` regenerates only the named icons (the others stay byte-identical).
ONLY=set(sys.argv[1:])
unknown=ONLY-set(ICONS)
if unknown: sys.exit(f"unknown icon(s): {', '.join(sorted(unknown))}")

OUT.mkdir(parents=True, exist_ok=True)
done=0
for name, painter in ICONS.items():
    if ONLY and name not in ONLY: continue
    done+=1
    image=Image.new("RGBA",(32,32),(0,0,0,0)); painter(ImageDraw.Draw(image))
    for scale in (1,2,3,4):
        target=image if scale==1 else image.resize((32*scale,32*scale),Image.Resampling.NEAREST)
        target.save(OUT/f"{name}-{32*scale}.png",optimize=True)
print(f"generated {done*4} icons in {OUT}")
