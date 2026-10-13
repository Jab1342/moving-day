"""Upgrade props and the box truck (Claude B). Same conventions as md_furniture.

    ns = {"__file__": r"<repo>/assets/blend/scripts/md_props.py"}
    exec(open(ns["__file__"]).read(), ns)
    ns["ship_prop"]("PRP_Dolly")
"""

import math
import os

import bpy
from mathutils import Matrix

_here = os.path.dirname(__file__)
exec(open(os.path.join(_here, "md_trucks.py")).read(), globals())

GROUND_TO_BED = 3.2  # pickup rig: wheels touch y=-2.4, bed floor top y=+0.8


def dolly():
    """Flat 4-caster furniture dolly; the load sits on the carpet at z=0.7."""
    p = [
        box("wood_oak", (3.0, 2.0, 0.2), (0, 0, 0.55), bevel=0.03),
        box("fab_navy", (2.9, 1.9, 0.05), (0, 0, 0.675)),  # carpet
    ]
    for x in (-1.3, 1.3):
        for y in (-0.8, 0.8):
            p.append(box("metal_gunmetal", (0.25, 0.25, 0.1), (x, y, 0.4)))  # caster plate
            p.append(cyl("rubber", 0.18, 0.12, (x - 0.06, y, 0.18), seg=8, axis="X"))
    return p


def strap():
    """Ratchet buckle with short band tails. Studio runs the long band as a Beam or thin part."""
    return [
        box("hazard_orange", (0.35, 1.6, 0.04), (0, 0, 0.02)),  # band
        box("metal_steel", (0.5, 0.45, 0.12), (0, 0, 0.1), bevel=0.02),  # ratchet body
        box("metal_gunmetal", (0.12, 0.6, 0.06), (0, 0.15, 0.19)),  # lever
        cyl("metal_steel", 0.1, 0.55, (-0.275, 0, 0.12), seg=6, axis="X"),  # spool
    ]


def loading_ramp():
    run = 8.0
    angle = math.atan2(GROUND_TO_BED, run)
    length = math.hypot(run, GROUND_TO_BED)
    p = [box("metal_brushed", (4.0, length, 0.15), (0, length / 2, 0.075))]
    for x in (-1.95, 1.95):
        p.append(box("hazard_orange", (0.15, length, 0.25), (x, length / 2, 0.2)))
    n = int(length / 0.6)
    for i in range(1, n):
        p.append(box("grey_dark", (3.7, 0.1, 0.05), (0, i * 0.6, 0.175)))
    ramp = join(p, "PRP_LoadingRamp")
    ramp.data.transform(Matrix.Rotation(angle, 4, "X"))  # tip up so the far end meets the bed
    # flat lip that rests on the bed floor, at the top end of the deck
    top_y = length * math.cos(angle) - 0.15 * math.sin(angle)
    top_z = length * math.sin(angle) + 0.15 * math.cos(angle)
    lip = box("metal_brushed", (4.0, 0.5, 0.08), (0, top_y + 0.2, top_z - 0.04), name="lip")
    return [ramp, lip]


def box_truck_body(cab="truck_blue", box_paint="truck_white"):
    p = [b for b in pickup_body(cab)]
    # drop the pickup's chassis, bed, tailgate, taillights and rear fenders; keep the cab half
    keep = []
    for o in p:
        ys = [v.co.y for v in o.data.vertices]
        if min(ys) >= 0.0 or (max(ys) > 8.0):
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.dimensions.y > 15:  # pickup chassis rail
            bpy.data.objects.remove(o, do_unlink=True)
        else:
            keep.append(o)
    keep += [
        box("nearblack", (6.2, 23.4, 0.8), (0, 3.8, 0)),  # chassis rail z -8..15.6
        box("grey_dark", (6.4, 15.0, 0.4), (0, 8.0, 0.6)),  # cargo floor (top at 0.8)
        box(box_paint, (0.3, 15.4, 6.1), (-3.35, 8.0, 3.85)),
        box(box_paint, (0.3, 15.4, 6.1), (3.35, 8.0, 3.85)),
        box(box_paint, (7.0, 0.3, 6.1), (0, 0.35, 3.85)),  # front wall
        box(box_paint, (7.0, 15.4, 0.3), (0, 8.0, 7.05), bevel=0.06),  # roof
        box("hazard_orange", (0.03, 15.0, 0.5), (-3.51, 8.0, 2.6)),  # side stripes
        box("hazard_orange", (0.03, 15.0, 0.5), (3.51, 8.0, 2.6)),
        box("grey_light", (6.4, 0.5, 0.7), (0, 15.45, 6.55)),  # rolled-up door
        box("grey_dark", (7.0, 0.5, 0.3), (0, 15.85, 0.3)),  # rear step
        box("taillight", (0.32, 0.1, 0.8), (-3.35, 15.73, 1.6)),
        box("taillight", (0.32, 0.1, 0.8), (3.35, 15.73, 1.6)),
    ]
    for x in (-3.65, 3.65):
        keep.append(box(box_paint, (1.4, 3.8, 0.3), (x, 11.5, 0.85), bevel=0.08))  # rear fenders
    return keep


PROPS = {
    "PRP_Dolly": dolly,
    "PRP_Strap": strap,
    "PRP_LoadingRamp": loading_ramp,
    "TRK_BoxTruck_Body": box_truck_body,
}


def ship_prop(name):
    clear_scene()
    setup_scene()
    _preview_light()
    obj = join(PROPS[name](), name)
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    centre = ((min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2, (min(ys) + max(ys)) / 2)  # Roblox X, Y, Z
    finalize(obj)
    export_fbx([obj], f"{name}.fbx")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, f"{name}.blend"))
    r = check(obj)
    r["rig_centre_roblox"] = tuple(round(c, 3) for c in centre)
    return r
