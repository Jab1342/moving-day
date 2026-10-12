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


BUILDERS = {
    "FUR_Couch": couch,
    "FUR_CardboardBox": cardboard_box,
    "FUR_Chair": chair,
    "FUR_Lamp": lamp,
    "FUR_Vase": vase,
    "FUR_TV": tv,
    "FUR_Mattress": mattress,
    "FUR_Fridge": fridge,
}

# name -> (chunk count, swatch for the freshly cut faces)
FRACTURE = {
    "FUR_Vase": (5, "offwhite"),
    "FUR_Lamp": (4, "grey_light"),
    "FUR_TV": (5, "charcoal"),
}


def _preview_light():
    sun = bpy.data.lights.get("PreviewSun") or bpy.data.lights.new("PreviewSun", "SUN")
    sun.energy = 3.0
    o = bpy.data.objects.new("PreviewSun", sun)
    o.rotation_euler = (0.9, 0.2, -0.6)  # from front-left-above
    bpy.context.collection.objects.link(o)


def build(name):
    clear_scene()
    setup_scene()
    _preview_light()
    obj = join(BUILDERS[name](), name)
    finalize(obj)
    return obj


def ship(name, seed=7):
    """Build, check, save the .blend and export FBX(es). Returns check results."""
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
