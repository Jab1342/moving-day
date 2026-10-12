"""Furniture builders (Claude B). Sizes match Claude A's Studio grayboxes.

Run inside Blender:
    ns = {"__file__": r"<repo>/assets/blend/scripts/md_furniture.py"}
    exec(open(ns["__file__"]).read(), ns)
    ns["ship"]("FUR_Couch")          # build, check, save .blend, export FBX (+ fracture set)

Roblox (X, Y, Z) graybox sizes map to Blender (X, Z, Y); front is Blender -Y (Roblox -Z).
"""

import os

import bpy

_here = os.path.dirname(__file__)
for _mod in ("md_pipeline.py", "md_shapes.py"):
    exec(open(os.path.join(_here, _mod)).read(), globals())


def couch():
    p = []
    for x in (-3.2, 3.2):
        for y in (-1.2, 1.2):
            p.append(cyl("wood_walnut", 0.15, 0.3, (x, y, 0), seg=6))
    p.append(box("fab_teal", (7, 3, 0.9), (0, 0, 0.75), bevel=0.08))
    for x in (-1.38, 1.38):
        p.append(box("fab_mint", (2.7, 2.2, 0.5), (x, -0.35, 1.45), bevel=0.1))
        p.append(box("fab_mint", (2.7, 0.5, 1.4), (x, 0.45, 2.35), bevel=0.1))
    p.append(box("fab_teal", (7, 0.8, 2.3), (0, 1.1, 2.35), bevel=0.12))
    for x in (-3.1, 3.1):
        p.append(box("fab_teal", (0.8, 3, 1.3), (x, 0, 1.85), bevel=0.12))
    return p


def cardboard_box():
    p = [box("cardboard", (2, 2, 2), (0, 0, 1), bevel=0.03)]
    p.append(box("tape", (0.5, 2.04, 0.02), (0, 0, 2.005)))
    for y in (-1.01, 1.01):
        p.append(box("tape", (0.5, 0.02, 0.6), (0, y, 1.7)))
    for x in (-1.005, 1.005):
        p.append(box("cardboard_dark", (0.02, 0.6, 0.2), (x, 0, 1.55)))
    p.append(box("cardboard_dark", (2.02, 0.02, 0.03), (0, -1.0, 1.98)))
    return p


def chair():
    p = []
    for x in (-0.8, 0.8):
        for y in (-0.8, 0.8):
            p.append(box("wood_oak", (0.25, 0.25, 1.6), (x, y, 0.8)))
        p.append(box("wood_oak", (0.25, 0.25, 1.95), (x, 0.8, 2.825)))
    p.append(box("wood_honey", (2, 2, 0.25), (0, 0, 1.725), bevel=0.04))
    p.append(box("fab_red", (1.8, 1.8, 0.15), (0, -0.05, 1.925), bevel=0.05))
    p.append(box("wood_honey", (2, 0.28, 0.45), (0, 0.8, 3.575), bevel=0.04))
    p.append(box("wood_honey", (1.4, 0.2, 0.25), (0, 0.8, 2.9)))
    return p


def lamp():
    shade = lambda f: "bulb_glow" if f.normal.z < -0.9 else "fab_cream"
    return [
        cyl("metal_gunmetal", 0.6, 0.15, (0, 0, 0), seg=12),
        cyl("metal_brass", 0.07, 4.0, (0, 0, 0.15), seg=6),
        cyl(shade, 0.8, 1.2, (0, 0, 4.0), seg=12, r_top=0.5),
    ]


def vase():
    prof = [(0.3, 0), (0.42, 0.08), (0.52, 0.4), (0.55, 0.8), (0.54, 1.0), (0.45, 1.35), (0.25, 1.7), (0.22, 1.88), (0.32, 2.1)]

    def sw(f):
        z = f.calc_center_median().z
        if f.normal.z > 0.9 and z > 2.0:
            return "charcoal"
        return "white" if 0.8 < z < 1.0 else "fab_blue"

    return [lathe(sw, prof, seg=12)]


def tv():
    return [
        box("nearblack", (1.4, 0.8, 0.12), (0, 0, 0.06), bevel=0.03),
        box("charcoal", (0.3, 0.2, 0.35), (0, 0.05, 0.295)),
        box("nearblack", (4, 0.25, 2.25), (0, 0, 1.575), bevel=0.03),
        box("screen_off", (3.8, 0.02, 2.05), (0, -0.13, 1.575)),
    ]


def mattress():
    sw = lambda f: "white" if abs(f.normal.z) > 0.9 else "fab_sky"
    return [box(sw, (4, 7, 0.8), (0, 0, 0.4), bevel=0.15)]


def fridge():
    return [
        box("appliance_white", (3, 2.9, 7), (0, 0.15, 3.5), bevel=0.08),
        box("appliance_white", (2.9, 0.15, 2.3), (0, -1.375, 5.75), bevel=0.04),
        box("appliance_white", (2.9, 0.15, 4.4), (0, -1.375, 2.35), bevel=0.04),
        box("metal_chrome", (0.12, 0.15, 1.2), (1.2, -1.525, 5.2)),
        box("metal_chrome", (0.12, 0.15, 1.8), (1.2, -1.525, 3.4)),
        box("grey_dark", (2.9, 0.05, 0.12), (0, -1.33, 0.06)),
    ]


def ico(sw, r, center, scale=(1, 1, 1), name="part"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    o = _obj(bm, name)
    paint(o, sw)
    return o


def piano():
    p = [
        box("wood_ebony", (6, 2.0, 4.35), (0, 0.6, 2.175), bevel=0.05),  # case
        box("wood_ebony", (6, 2.0, 0.15), (0, 0.6, 4.425), bevel=0.04),  # lid
        box("wood_mahogany", (5.4, 0.05, 1.5), (0, -0.42, 3.35)),  # upper front panel
        box("wood_ebony", (5.8, 1.2, 0.35), (0, -1.0, 2.3)),  # keybed
        box("white", (5.2, 0.8, 0.08), (0, -1.05, 2.51)),  # white keys
        box("wood_ebony", (5.8, 0.15, 0.35), (0, -1.525, 2.55)),  # key slip lip
    ]
    for x in (-2.6, 2.6):
        p.append(box("wood_ebony", (0.3, 0.3, 2.15), (x, -1.35, 1.075)))
    octave = 5.2 / 6  # 6 octaves of black keys, 5 per octave
    for o in range(6):
        for k in (1, 2, 4, 5, 6):
            x = -2.6 + o * octave + k * octave / 7
            p.append(box("black", (0.06, 0.45, 0.08), (x, -1.2, 2.58)))
    for x in (-0.3, 0, 0.3):
        p.append(box("metal_brass", (0.12, 0.4, 0.08), (x, -0.5, 0.25)))
    return p


def aquarium():
    p = [
        box("wood_walnut", (5, 2, 2.5), (0, 0, 1.25), bevel=0.05),  # stand
        box("wood_darkwalnut", (2.2, 0.05, 1.8), (-1.2, -1.0, 1.25)),  # cabinet doors
        box("wood_darkwalnut", (2.2, 0.05, 1.8), (1.2, -1.0, 1.25)),
        box("sand", (4.8, 1.8, 0.3), (0, 0, 2.65)),
        box("water", (4.8, 1.8, 1.9), (0, 0, 3.75)),
        box("metal_gunmetal", (5, 2, 0.15), (0, 0, 2.575)),
        box("metal_gunmetal", (5, 2, 0.15), (0, 0, 4.925)),
        box("fab_orange", (0.5, 0.06, 0.3), (-1.0, -0.92, 3.9)),
        box("truck_yellow", (0.5, 0.06, 0.3), (1.2, -0.92, 3.4)),
        box("leaf", (0.15, 0.06, 1.0), (-1.9, -0.92, 3.3)),
        box("leaf_dark", (0.15, 0.06, 0.7), (-1.65, -0.92, 3.15)),
    ]
    for x in (-2.44, 2.44):
        for y in (-0.94, 0.94):
            p.append(box("metal_gunmetal", (0.12, 0.12, 2.5), (x, y, 3.75)))
    return p


def grandfather_clock():
    return [
        box("wood_mahogany", (1.8, 1.25, 1.5), (0, 0, 0.75), bevel=0.05),  # base
        box("wood_mahogany", (1.4, 1.0, 3.5), (0, 0.1, 3.25)),  # trunk
        box("mirror", (0.8, 0.05, 2.2), (0, -0.41, 3.1)),  # pendulum window
        cyl("metal_brass", 0.3, 0.06, (0, -0.47, 2.4), seg=10, axis="Y"),  # pendulum bob
        box("metal_brass", (0.06, 0.04, 1.2), (0, -0.45, 3.1)),  # pendulum rod
        box("wood_mahogany", (1.8, 1.25, 1.6), (0, 0, 5.8), bevel=0.05),  # hood
        prism("wood_mahogany", (-0.9, 0.9, -0.625, 0.625, 6.6), (-0.55, 0.55, -0.45, 0.45, 7.0)),  # crown
        cyl("paper", 0.55, 0.05, (0, -0.68, 5.8), seg=12, axis="Y"),  # dial
        cyl("metal_brass", 0.62, 0.03, (0, -0.65, 5.8), seg=12, axis="Y"),  # bezel
        box("nearblack", (0.06, 0.04, 0.42), (0, -0.74, 5.95)),  # hands
        box("nearblack", (0.3, 0.04, 0.06), (0.12, -0.74, 5.8)),
    ]


def bookshelf():
    p = [
        box("wood_oak", (0.2, 1.2, 6), (-1.9, 0, 3)),
        box("wood_oak", (0.2, 1.2, 6), (1.9, 0, 3)),
        box("wood_honey", (3.6, 0.1, 6), (0, 0.55, 3)),
    ]
    for z in (0.1, 1.5, 3.0, 4.5, 5.9):
        p.append(box("wood_oak", (3.6, 1.1, 0.2), (0, 0, z)))
    colours = ["fab_red", "fab_navy", "fab_mustard", "fab_forest", "fab_plum", "fab_cream", "fab_teal", "fab_brick"]
    rng = random.Random(4)
    for shelf_z in (0.2, 1.6, 3.1, 4.6):
        x = -1.7
        while x < 1.5:
            w = rng.choice((0.18, 0.22, 0.26, 0.3))
            h = rng.uniform(0.8, 1.15)
            if rng.random() < 0.15:
                x += 0.3  # gap
                continue
            p.append(box(rng.choice(colours), (w, 0.8, h), (x + w / 2, 0.05, shelf_z + h / 2)))
            x += w + 0.02
    return p


def microwave():
    p = [
        box("metal_steel", (2.4, 1.6, 1.4), (0, 0.02, 0.7), bevel=0.06),
        box("screen_off", (1.5, 0.05, 1.0), (-0.3, -0.8, 0.7)),
        box("grey_dark", (0.6, 0.05, 1.1), (0.8, -0.8, 0.7)),
        box("metal_chrome", (0.06, 0.08, 0.9), (0.42, -0.83, 0.7)),  # door handle
    ]
    for i, z in enumerate((1.05, 0.85, 0.65)):
        p.append(box("screen_glow" if i == 0 else "grey_light", (0.4, 0.04, 0.12), (0.8, -0.83, z)))
    return p


def potted_plant():
    pot = [(0.55, 0), (0.7, 0.05), (0.85, 1.1), (0.92, 1.2), (0.92, 1.3), (0.0, 1.3)]
    soil = lambda f: "soil" if f.normal.z > 0.9 and f.calc_center_median().z > 1.25 else "terracotta"
    p = [lathe(soil, pot, seg=10)]
    rng = random.Random(9)
    blobs = [(0, 0, 2.5, 0.75), (-0.55, 0.2, 2.1, 0.55), (0.55, -0.15, 2.2, 0.55), (0.1, -0.5, 2.0, 0.5), (0.2, 0.45, 2.9, 0.5), (-0.3, -0.2, 3.1, 0.45)]
    for i, (x, y, z, r) in enumerate(blobs):
        p.append(ico("leaf" if i % 2 == 0 else "leaf_dark", r, (x, y, z), scale=(1.1, 1.1, 0.95)))
    p.append(box("soil", (0.12, 0.12, 0.6), (0, 0, 1.55)))  # stem
    return p


def mirror():
    return [
        box("wood_honey", (2.4, 0.3, 4.0), (0, 0, 2.0), bevel=0.05),
        box("mirror", (2.0, 0.05, 3.6), (0, -0.16, 2.0)),
        box("wood_honey", (0.25, 0.05, 0.25), (0, 0.17, 3.5)),  # hanging block on the back
    ]


BUILDERS = {
    "FUR_Couch": couch,
    "FUR_CardboardBox": cardboard_box,
    "FUR_Chair": chair,
    "FUR_Lamp": lamp,
    "FUR_Vase": vase,
    "FUR_TV": tv,
    "FUR_Mattress": mattress,
    "FUR_Fridge": fridge,
    "FUR_Piano": piano,
    "FUR_Aquarium": aquarium,
    "FUR_GrandfatherClock": grandfather_clock,
    "FUR_Bookshelf": bookshelf,
    "FUR_Microwave": microwave,
    "FUR_PottedPlant": potted_plant,
    "FUR_Mirror": mirror,
}

# name -> (chunk count, swatch for the freshly cut faces)
FRACTURE = {
    "FUR_Vase": (5, "offwhite"),
    "FUR_Lamp": (4, "grey_light"),
    "FUR_TV": (5, "charcoal"),
    "FUR_Couch": (5, "fab_cream"),
    "FUR_CardboardBox": (4, "cardboard_dark"),
    "FUR_Chair": (4, "wood_pale"),
    "FUR_Mattress": (4, "offwhite"),
    "FUR_Fridge": (5, "grey_light"),
    "FUR_Piano": (6, "wood_pale"),
    "FUR_Aquarium": (6, "water_deep"),
    "FUR_GrandfatherClock": (5, "wood_pale"),
    "FUR_Bookshelf": (5, "wood_pale"),
    "FUR_Microwave": (4, "grey_light"),
    "FUR_PottedPlant": (4, "soil"),
    "FUR_Mirror": (5, "glass"),
}


def _preview_light():
    sun = bpy.data.lights.get("PreviewSun") or bpy.data.lights.new("PreviewSun", "SUN")
    sun.energy = 3.0
    o = bpy.data.objects.new("PreviewSun", sun)
    o.rotation_euler = (0.9, 0.2, -0.6)  # from front-left-above
    bpy.context.collection.objects.link(o)


# Seeds picked so every chunk stays under the 300-triangle budget.
FRACTURE_SEEDS = {"FUR_Piano": 11}


def build(name):
    clear_scene()
    setup_scene()
    _preview_light()
    obj = join(BUILDERS[name](), name)
    finalize(obj)
    return obj


def ship(name, seed=7):
    """Build, check, save the .blend and export FBX(es). Returns check results."""
    seed = FRACTURE_SEEDS.get(name, seed)
    obj = build(name)
    results = [check(obj)]
    export_fbx([obj], f"{name}.fbx")
    if name in FRACTURE:
        n, inner = FRACTURE[name]
        chunks = fracture(obj, n, inner, seed=seed)
        results += [check(c) for c in chunks]
        export_fbx(chunks, f"{name}_Frac.fbx")
        for c in chunks:  # keep the set in the .blend, offset to the side so the item stays readable
            c.location.x += obj.dimensions.x + 2
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, f"{name}.blend"))
    return results
