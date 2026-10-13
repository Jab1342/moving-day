"""P2 meshes (Claude B): HQ and town props, cosmetic hats. Decoration only, no readable text.

    ns = {"__file__": r"<repo>/assets/blend/scripts/md_p2.py"}
    exec(open(ns["__file__"]).read(), ns)
    ns["ship_prop"]("PRP_Tree")

Signs and boards have a blank face on Blender -Y (Roblox Front, -Z) for a SurfaceGui.
Hats: origin at the bottom centre = where the hat sits on the head; Studio adds the
Handle/HatAttachment.
"""

import os
import random

_here = os.path.dirname(__file__)
exec(open(os.path.join(_here, "md_props.py")).read(), globals())


# ---- HQ -----------------------------------------------------------------

def hq_sign():
    return [
        box("nearblack", (30, 1, 6), (0, 0, 3), bevel=0.1),
        box("truck_yellow", (29, 0.05, 5), (0, -0.52, 3)),  # blank face for the SurfaceGui
    ]


def garage_door():
    p = []
    for i, z in enumerate((1.5, 4.5, 7.5, 10.5)):
        p.append(box("white", (12, 0.3, 2.9), (0, 0, z)))
        p.append(box("grey_light", (12, 0.35, 0.1), (0, 0, z + 1.5)))  # section seams
    for x in (-4.5, -1.5, 1.5, 4.5):
        p.append(box("glass", (2.2, 0.05, 0.9), (x, -0.17, 7.6)))
    p.append(box("metal_gunmetal", (1.0, 0.15, 0.15), (0, -0.22, 1.2)))  # handle
    return p


def shelving():
    p = []
    for x in (-3.9, 3.9):
        for y in (-1.1, 1.1):
            p.append(box("fab_navy", (0.25, 0.25, 8), (x, y, 4)))
    for z in (0.4, 3.0, 5.6, 7.9):
        for y in (-1.1, 1.1):
            p.append(box("hazard_orange", (7.6, 0.2, 0.3), (0, y, z)))
        p.append(box("wood_birch", (7.6, 2.2, 0.1), (0, 0, z + 0.2)))
    rng = random.Random(3)
    for z in (0.65, 3.25, 5.85):
        x = -3.5
        while x < 3.0:
            w = rng.uniform(1.0, 1.6)
            h = rng.uniform(0.8, 1.6)
            if x + w > 3.7:
                break
            if rng.random() > 0.2:
                p.append(box(rng.choice(("cardboard", "cardboard_dark")), (w, 1.6, h), (x + w / 2, 0, z + h / 2)))
            x += w + 0.25
    return p


def crew_pad_board():
    return [
        box("grey_mid", (0.3, 0.3, 7.0), (-2.7, 0, 3.5)),
        box("grey_mid", (0.3, 0.3, 7.0), (2.7, 0, 3.5)),
        box("truck_yellow", (6.0, 0.3, 3.6), (0, 0, 5.3), bevel=0.06),
        box("white", (5.6, 0.05, 3.2), (0, -0.17, 5.3)),  # blank face for the SurfaceGui
    ]


# ---- town ----------------------------------------------------------------

def mailbox():
    return [
        box("wood_oak", (0.3, 0.3, 3.4), (0, 0.2, 1.7)),
        box("fab_navy", (0.9, 1.6, 0.45), (0, 0, 3.6)),
        cyl("fab_navy", 0.45, 1.6, (0, -0.8, 3.825), seg=10, axis="Y"),
        box("truck_red", (0.06, 0.12, 0.7), (0.5, 0.4, 4.0)),  # flag post
        box("truck_red", (0.06, 0.4, 0.25), (0.5, 0.25, 4.25)),  # flag
    ]


def bin_():
    return [
        prism("fab_forest", (-0.8, 0.8, -0.8, 0.8, 0.2), (-0.95, 0.95, -1.0, 1.0, 3.0)),
        box("leaf_dark", (2.0, 2.1, 0.15), (0, 0.0, 3.075), bevel=0.03),  # lid
        box("grey_dark", (1.6, 0.15, 0.15), (0, 1.1, 2.9)),  # handle bar
        cyl("rubber", 0.3, 0.2, (-0.95, 0.75, 0.3), seg=8, axis="X"),
        cyl("rubber", 0.3, 0.2, (0.75, 0.75, 0.3), seg=8, axis="X"),
    ]


def tree():
    return [
        cyl("wood_walnut", 0.6, 6.0, (0, 0, 0), seg=6, r_top=0.4),
        ico("leaf", 3.6, (0, 0, 8.2), scale=(1, 1, 0.9)),
        ico("leaf_dark", 2.6, (-1.8, 0.8, 7.0)),
        ico("leaf_dark", 2.4, (1.9, -0.6, 7.3)),
        ico("leaf", 2.2, (0.3, 0.4, 11.0)),
    ]


def streetlight():
    head = lambda f: "bulb_glow" if f.normal.z < -0.9 else "metal_gunmetal"
    return [
        cyl("metal_gunmetal", 0.6, 0.6, (0, 0, 0), seg=8),
        cyl("grey_mid", 0.22, 15.0, (0, 0, 0.6), seg=8, r_top=0.16),
        box("grey_mid", (0.25, 4.2, 0.25), (0, -2.0, 15.4)),
        box(head, (1.0, 1.8, 0.45), (0, -4.0, 15.2), bevel=0.06),
    ]


def fence():
    p = [
        box("white", (8, 0.15, 0.3), (0, 0.1, 0.9)),
        box("white", (8, 0.15, 0.3), (0, 0.1, 2.6)),
    ]
    for i in range(10):
        x = -3.6 + i * 0.8
        p.append(prism("white", (x - 0.2, x + 0.2, -0.06, 0.06, 0), (x - 0.2, x + 0.2, -0.06, 0.06, 3.2)))
        p.append(prism("white", (x - 0.2, x + 0.2, -0.06, 0.06, 3.2), (x - 0.02, x + 0.02, -0.02, 0.02, 3.5)))
    return p


# ---- hats -----------------------------------------------------------------

def _hard_hat(colour):
    dome = [(0.95, 0.0), (0.95, 0.07), (0.72, 0.1), (0.72, 0.35), (0.63, 0.58), (0.42, 0.75), (0.0, 0.8)]
    return [
        lathe(colour, dome, seg=14),
        box(colour, (0.16, 1.3, 0.12), (0, 0, 0.74), bevel=0.03),  # ridge
    ]


def hard_hat():
    return _hard_hat("truck_yellow")


def hard_hat_gold():
    return _hard_hat("metal_brass")


def trucker_cap():
    crown = [(0.66, 0.0), (0.64, 0.3), (0.48, 0.55), (0.0, 0.62)]
    front = lambda f: "fab_blue" if f.normal.y < -0.2 else "white"
    return [
        lathe(front, crown, seg=12),
        prism("fab_blue", (-0.5, 0.5, -1.25, -0.55, 0.04), (-0.48, 0.48, -1.2, -0.55, 0.1)),  # bill
        box("fab_blue", (0.12, 0.12, 0.06), (0, 0, 0.64)),  # button
    ]


def beanie():
    body = [(0.63, 0.0), (0.65, 0.25), (0.61, 0.5), (0.46, 0.7), (0.2, 0.82), (0.0, 0.84)]
    cuff = [(0.68, 0.0), (0.69, 0.24), (0.0, 0.24)]
    return [
        lathe("fab_red", body, seg=12),
        lathe("fab_cream", cuff, seg=12),
        ico("white", 0.18, (0, 0, 0.9)),
    ]


P2 = {
    "PRP_HQSign": hq_sign,
    "PRP_GarageDoor": garage_door,
    "PRP_Shelving": shelving,
    "PRP_CrewPadBoard": crew_pad_board,
    "PRP_Mailbox": mailbox,
    "PRP_Bin": bin_,
    "PRP_Tree": tree,
    "PRP_Streetlight": streetlight,
    "PRP_Fence": fence,
    "COS_HardHat": hard_hat,
    "COS_HardHatGold": hard_hat_gold,
    "COS_TruckerCap": trucker_cap,
    "COS_Beanie": beanie,
}
PROPS.update(P2)
