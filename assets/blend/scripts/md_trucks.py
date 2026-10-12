"""Truck meshes (Claude B). Modelled in Claude A's TRK_Pickup rig space, then finalized.

Rig (Roblox, relative to Chassis pivot): chassis 6.6 x 0.8 x 16, bed floor top y=0.8,
inner bed 6.2 x 7.4 centred z=+4.2, cab z -4.6..0 up to y=4.3, hood to z=-8.0,
wheels r=1.5 x 1.4 wide at x=+-3.6, y=-0.9, z=-5.4 / +5.0.
Blender: X = Roblox X, Y = Roblox Z (front -Y), Z = Roblox Y.

The body is a VISUAL mesh: Hull collision would fill the open bed, so Studio keeps the
rig's own parts as invisible collision and sets this MeshPart CanCollide=false.
"""

import os

import bmesh
import bpy

_here = os.path.dirname(__file__)
exec(open(os.path.join(_here, "md_furniture.py")).read(), globals())


def pickup_body(paint_main="truck_red"):
    glass = lambda f: "glass" if (abs(f.normal.x) > 0.7 or abs(f.normal.y) > 0.3) else paint_main
    p = [
        box("nearblack", (6.2, 15.4, 0.8), (0, 0, 0)),  # chassis rail
        prism(paint_main, (-3.3, 3.3, -8.0, -4.6, 0.4), (-3.3, 3.3, -7.8, -4.6, 2.0)),  # hood, slight nose slope
        box("grey_dark", (5.0, 0.1, 0.9), (0, -8.03, 1.05)),  # grille
        box("headlight", (1.0, 0.12, 0.5), (-2.5, -8.0, 1.45)),
        box("headlight", (1.0, 0.12, 0.5), (2.5, -8.0, 1.45)),
        box("grey_mid", (7.0, 0.4, 0.6), (0, -8.1, 0.2), bevel=0.08),  # bumper
        box(paint_main, (6.6, 4.6, 1.8), (0, -2.3, 1.3)),  # cab lower
        prism(glass, (-3.2, 3.2, -4.5, -0.1, 2.2), (-3.2, 3.2, -3.7, -0.1, 4.0)),  # cab glasshouse, raked windshield
        box(paint_main, (6.6, 4.0, 0.3), (0, -1.95, 4.15), bevel=0.08),  # roof
        box("nearblack", (0.4, 0.15, 0.35), (-3.5, -4.3, 2.6)),  # mirrors
        box("nearblack", (0.4, 0.15, 0.35), (3.5, -4.3, 2.6)),
        box("grey_dark", (6.2, 7.4, 0.4), (0, 4.2, 0.6)),  # bed floor
        box(paint_main, (0.4, 7.4, 1.8), (-3.1, 4.2, 1.7)),
        box(paint_main, (0.4, 7.4, 1.8), (3.1, 4.2, 1.7)),
        box(paint_main, (6.6, 0.4, 1.8), (0, 0.3, 1.7)),  # bed front
        box(paint_main, (6.6, 0.4, 1.0), (0, 8.1, 1.3)),  # tailgate
        box("taillight", (0.42, 0.1, 0.6), (-3.1, 7.93, 2.1)),
        box("taillight", (0.42, 0.1, 0.6), (3.1, 7.93, 2.1)),
        box("grey_dark", (0.8, 6.0, 0.2), (-3.6, -0.2, 0.15)),  # running boards
        box("grey_dark", (0.8, 6.0, 0.2), (3.6, -0.2, 0.15)),
    ]
    for y in (-5.4, 5.0):  # fenders over the wheels
        for x in (-3.65, 3.65):
            p.append(box(paint_main, (1.4, 3.8, 0.3), (x, y, 0.85), bevel=0.08))
    return p


def pickup_wheel():
    return [
        cyl("tire", 1.5, 1.4, (-0.7, 0, 0), seg=12, axis="X"),
        cyl("metal_steel", 0.75, 0.06, (0.7, 0, 0), seg=8, axis="X"),
        cyl("metal_steel", 0.75, 0.06, (-0.76, 0, 0), seg=8, axis="X"),
    ]


TRUCKS = {"TRK_Pickup_Body": pickup_body, "TRK_Pickup_Wheel": pickup_wheel}


def ship_truck(name):
    clear_scene()
    setup_scene()
    _preview_light()
    obj = join(TRUCKS[name](), name)
    # Record where the mesh sits in rig space before finalize moves it to bottom centre.
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
