"""Moving Day Blender pipeline helpers (Claude B).

Run inside Blender:  exec(open(r"<repo>/assets/blend/scripts/md_pipeline.py").read())

Conventions (SPEC section 7):
  * 1 Blender unit = 1 stud. Scene unit scale is locked to UNIT_SCALE below once
    the reference cube passes in Studio.
  * Front faces Blender -Y, origin at bottom centre, transforms applied.
  * Every mesh uses the one "MD_Palette" material (assets/blend/palette.png);
    UVs are snapped onto swatch centres, never painted.
"""

import json
import os

import bmesh
import bpy

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..")) if "__file__" in globals() else r"C:\Users\jettg\OneDrive\onedrive\Documents\ChatGPT\Moving Day"
BLEND_DIR = os.path.join(REPO, "assets", "blend")
EXPORT_DIR = os.path.join(REPO, "assets", "export")
PALETTE_PNG = os.path.join(BLEND_DIR, "palette.png")
PALETTE_JSON = os.path.join(BLEND_DIR, "palette.json")

UNIT_SCALE = 0.01  # 1 BU shows as 1 cm in Blender, written as 1 FBX cm, read as 1 stud
BUDGETS = {"FUR": 1500, "HERO": 4000, "TRK": 8000, "FRAC_CHUNK": 300, "PRP": 1500, "COS": 1500, "REF": 100}
HERO_ITEMS = {"FUR_Piano", "FUR_Aquarium", "FUR_GrandfatherClock"}

_PALETTE = None


def palette():
    global _PALETTE
    if _PALETTE is None:
        with open(PALETTE_JSON) as f:
            _PALETTE = json.load(f)["swatches"]
    return _PALETTE


def setup_scene():
    s = bpy.context.scene
    s.unit_settings.system = "METRIC"
    s.unit_settings.scale_length = UNIT_SCALE
    s.unit_settings.length_unit = "CENTIMETERS"
    # Keep viewport usable at stud scale
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type == "VIEW_3D":
            area.spaces[0].clip_end = 10000
    return s


def palette_material():
    mat = bpy.data.materials.get("MD_Palette")
    if mat:
        return mat
    mat = bpy.data.materials.new("MD_Palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    img = bpy.data.images.get("palette.png") or bpy.data.images.load(PALETTE_PNG, check_existing=True)
    img.filepath = PALETTE_PNG
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    tex.location = (-400, 0)
    nt.links.new(tex.outputs[0], bsdf.inputs[0])
    for key in ("Roughness",):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = 0.8
    return mat


def paint(obj, face_swatch):
    """Snap UVs of faces onto swatches.

    face_swatch: a swatch name for the whole mesh, or a callable(face) -> swatch name
    (faces are bmesh faces in object space).
    """
    pal = palette()
    me = obj.data
    if not me.materials:
        me.materials.append(palette_material())
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        name = face_swatch(f) if callable(face_swatch) else face_swatch
        u, v = pal[name]["uv"]
        for loop in f.loops:
            loop[uv].uv = (u, v)
        f.smooth = False
    bm.to_mesh(me)
    bm.free()
    me.update()


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def budget_for(name):
    if name in HERO_ITEMS:
        return BUDGETS["HERO"]
    if name.startswith("FUR_") and "_Frac" in name:
        return BUDGETS["FRAC_CHUNK"]
    return BUDGETS.get(name.split("_", 1)[0], 1500)


def finalize(obj):
    """Apply transforms and put the origin at the bottom centre of the bounding box."""
    obj.data.transform(obj.matrix_basis)
    obj.matrix_basis.identity()
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    off = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs))
    for v in obj.data.vertices:
        v.co.x -= off[0]
        v.co.y -= off[1]
        v.co.z -= off[2]
    obj.location = (0, 0, 0)
    obj.data.update()


def check(obj):
    tris = tri_count(obj)
    lim = budget_for(obj.name)
    dims = tuple(round(d, 3) for d in obj.dimensions)
    ok = tris <= lim and all(abs(s - 1) < 1e-6 for s in obj.scale) and obj.location.length < 1e-6
    return {"name": obj.name, "tris": tris, "budget": lim, "dims_xyz": dims, "ok": ok}


def export_fbx(objs, filename):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, filename)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        axis_forward="-Z",
        axis_up="Y",
        # Without this the Z-up -> Y-up swap lands in each node's rotation and Roblox
        # puts a -90 deg X rotation into MeshPart.PivotOffset. Uploads before P2 have it.
        bake_space_transform=True,
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="STRIP",
        embed_textures=False,
    )
    return path
