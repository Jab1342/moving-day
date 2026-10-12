"""Low-poly building blocks for Moving Day meshes (Claude B).

Blender axes, in studs: X = width, Y = depth (front is -Y), Z = up, floor at z = 0.
Each helper returns a new object painted with one palette swatch, or with a
callable(face) -> swatch name. Load md_pipeline first: exec this file into the
same namespace (it uses paint/palette/finalize/check/export_fbx from there).
"""

import math
import random

import bmesh
import bpy
from mathutils import Vector


def _obj(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def box(sw, size, center=(0, 0, 0), bevel=0.0, name="part"):
    """Box of size (x, y, z) centred at center."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    o = _obj(bm, name)
    paint(o, sw)
    return o


def cyl(sw, r, h, base=(0, 0, 0), seg=8, r_top=None, axis="Z", name="part"):
    """Cylinder or cone standing on base (bottom centre); axis X/Y lays it down with base at its -axis end."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r_top is None else r_top, depth=h)
    bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    if axis == "X":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=_rot("Y", 90), verts=bm.verts)
    elif axis == "Y":
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=_rot("X", -90), verts=bm.verts)
    bmesh.ops.translate(bm, vec=base, verts=bm.verts)
    o = _obj(bm, name)
    paint(o, sw)
    return o


def lathe(sw, profile, seg=12, base=(0, 0, 0), name="part"):
    """Surface of revolution around Z. profile = [(radius, z), ...] bottom to top; ends are capped."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[i], b[0], a[j]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    if len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    if len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, vec=base, verts=bm.verts)
    o = _obj(bm, name)
    paint(o, sw)
    return o


def _rot(axis, deg):
    from mathutils import Matrix

    return Matrix.Rotation(math.radians(deg), 3, axis)


def join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    return o


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def _volume(bm):
    if not bm.verts:
        return 0.0
    lo = Vector((min(v.co.x for v in bm.verts), min(v.co.y for v in bm.verts), min(v.co.z for v in bm.verts)))
    hi = Vector((max(v.co.x for v in bm.verts), max(v.co.y for v in bm.verts), max(v.co.z for v in bm.verts)))
    d = hi - lo
    return d.x * d.y * d.z + 1e-4 * (d.x + d.y + d.z)


def _half(src, co, no, keep_inner, inner_uv):
    bm = src.copy()
    res = bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), dist=1e-5, plane_co=co, plane_no=no, clear_outer=keep_inner, clear_inner=not keep_inner)
    cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge) and e.is_valid and e.is_boundary]
    if cut:
        filled = bmesh.ops.holes_fill(bm, edges=cut, sides=0)
        uv = bm.loops.layers.uv.verify()
        for f in filled["faces"]:
            for loop in f.loops:
                loop[uv].uv = inner_uv
    return bm


def fracture(obj, chunks, inner_swatch, seed=1, min_verts=4):
    """Split obj into `chunks` pieces by recursive plane cuts. Pieces keep obj's object space
    (all origins at the item's origin) so they spawn assembled where the item was."""
    rng = random.Random(seed)
    inner_uv = tuple(palette()[inner_swatch]["uv"])
    base = bmesh.new()
    base.from_mesh(obj.data)
    pieces = [base]
    tries = 0
    while len(pieces) < chunks and tries < 200:
        tries += 1
        pieces.sort(key=_volume, reverse=True)
        bm = pieces[0]
        c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        c += Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1)))
        n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        if n.length < 0.2:
            continue
        n.normalize()
        a = _half(bm, c, n, True, inner_uv)
        b = _half(bm, c, n, False, inner_uv)
        if len(a.verts) < min_verts or len(b.verts) < min_verts or min(_volume(a), _volume(b)) < 0.08 * _volume(bm):
            a.free()
            b.free()
            continue
        pieces.pop(0).free()
        pieces += [a, b]
    out = []
    for i, bm in enumerate(sorted(pieces, key=lambda p: -_volume(p)), 1):
        name = f"{obj.name}_Frac_{i}"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        if obj.data.materials:
            me.materials.append(obj.data.materials[0])
        o = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(o)
        out.append(o)
    return out
