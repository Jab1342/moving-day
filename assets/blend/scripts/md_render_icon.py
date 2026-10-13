"""Reference render for Codex's game icon (Claude B). Uses only this repo's meshes.

    ns = {"__file__": r"<repo>/assets/blend/scripts/md_render_icon.py"}
    exec(open(ns["__file__"]).read(), ns)
    ns["render_icon"]()   # -> assets/renders/icon_reference.png (1024x1024)
"""

import math
import os

import bpy
from mathutils import Vector

_here = os.path.dirname(__file__)
exec(open(os.path.join(_here, "md_p2.py")).read(), globals())

RENDERS = os.path.join(REPO, "assets", "renders")


def _place(name, loc, rot_deg=(0, 0, 0), new_name=None):
    with bpy.data.libraries.load(os.path.join(BLEND_DIR, name + ".blend")) as (src, dst):
        dst.objects = [name]
    o = dst.objects[0]
    if new_name:
        o.name = new_name
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot_deg]
    return o


def _mover(x, y, facing_deg, shirt):
    """Generic blocky mover: legs, torso, head, arms reaching forward (local -Y)."""
    parts = [
        box("fab_navy", (0.9, 0.9, 2.0), (-0.5, 0, 1.0)),
        box("fab_navy", (0.9, 0.9, 2.0), (0.5, 0, 1.0)),
        box(shirt, (2.0, 1.0, 2.0), (0, 0, 3.0)),
        box("fab_tan", (1.1, 1.1, 1.1), (0, 0, 4.6)),
        box(shirt, (0.8, 2.0, 0.8), (-1.4, -0.7, 3.4)),
        box(shirt, (0.8, 2.0, 0.8), (1.4, -0.7, 3.4)),
        box("nearblack", (0.2, 0.05, 0.2), (-0.25, -0.56, 4.75)),  # eyes
        box("nearblack", (0.2, 0.05, 0.2), (0.25, -0.56, 4.75)),
    ]
    m = join(parts, f"Mover_{shirt}")
    m.rotation_euler = (0, 0, math.radians(facing_deg))
    m.location = (x, y, 0)
    hat = _place("COS_HardHat", (0, 0, 0), new_name=f"Hat_{shirt}")
    hat.parent = m
    hat.location = (0, 0, 5.15)
    return m


def build_scene():
    """Call after bpy.ops.wm.read_homefile(use_empty=True) in a separate script run."""
    setup_scene()
    # truck: body bottom sits 2.0 above ground, wheels on the ground
    _place("TRK_Pickup_Body", (0, 0, 2.0))
    for x in (-3.6, 3.6):
        for y in (-5.4, 5.0):
            _place("TRK_Pickup_Wheel", (x, y, 0), new_name=f"Wheel_{x}_{y}")
    bed = 2.8  # bed floor top above ground
    _place("FUR_CardboardBox", (-1.8, 2.2, bed))
    _place("FUR_CardboardBox", (-1.6, 2.4, bed + 2.0), (0, 0, 14))
    _place("FUR_Lamp", (1.9, 1.6, bed), (0, 0, 0))
    _place("FUR_TV", (1.2, 4.0, bed), (0, 0, -8))
    _place("FUR_Vase", (5.2, 9.6, 5.2), (55, -30, 0))  # tumbling off the side
    # couch carried toward the tailgate, long axis along Y
    _place("FUR_Couch", (0, 14.6, 2.6), (6, 0, 90))
    _mover(0, 10.2, 180, "fab_blue")  # walking backwards to the truck, facing the couch (+Y)
    _mover(0, 19.0, 0, "fab_orange")
    # ground + sky
    gme = bpy.data.meshes.new("Ground")
    gme.from_pydata([(-200, -200, 0), (200, -200, 0), (200, 200, 0), (-200, 200, 0)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new("Ground", gme)
    bpy.context.collection.objects.link(g)
    gm = bpy.data.materials.new("Ground")
    gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs[0].default_value = (0.32, 0.55, 0.25, 1)
    g.data.materials.append(gm)
    world = bpy.data.worlds.new("Sky")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.55, 0.78, 1.0, 1)
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.context.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 40
    bpy.context.collection.objects.link(cam)
    cam.location = (19, 30, 13)
    target = Vector((0.5, 7.5, 2.8))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam


def render_icon(size=1024):
    build_scene()
    s = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            s.render.engine = engine
            break
        except TypeError:
            continue
    s.render.resolution_x = s.render.resolution_y = size
    s.render.film_transparent = False
    os.makedirs(RENDERS, exist_ok=True)
    s.render.filepath = os.path.join(RENDERS, "icon_reference.png")
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, "REN_IconReference.blend"))
    return s.render.filepath
