# Export manifest (Claude B)

One FBX per asset. Units: 1 Blender unit = 1 stud (scene unit scale 0.01, FBX written in cm).
Front faces Blender -Y (Roblox -Z), origin at bottom centre, transforms applied, one shared palette
material (`assets/blend/palette.png`, uploaded as PAL_Palette 76201554143630; set MeshPart.TextureID).
Grip points and collision proxies are added in Studio.

**PivotOffset:** assets marked `-90X` were exported before `bake_space_transform` and carry a -90 deg X
rotation in MeshPart.PivotOffset; fix on insert with `part.PivotOffset = CFrame.new(part.PivotOffset.Position)`.

| File | Asset ID | Studio target | Collision fidelity | Pivot | Notes |
| --- | --- | --- | --- | --- | --- |
| REF_Cube.fbx | 130690847988883 | (test only, deleted) | Box | -90X | 4x1x2 scale check |
| FUR_Couch.fbx | 117885384302333 | Assets.Furniture | Hull | -90X |  |
| FUR_CardboardBox.fbx | 138491826737911 | Assets.Furniture | Hull | -90X |  |
| FUR_Chair.fbx | 87164841731172 | Assets.Furniture | Hull | -90X |  |
| FUR_Lamp.fbx | 109935049563599 | Assets.Furniture | Hull | -90X |  |
| FUR_Vase.fbx | 105037063887993 | Assets.Furniture | Hull | -90X |  |
| FUR_TV.fbx | 84936548740594 | Assets.Furniture | Hull | -90X |  |
| FUR_Mattress.fbx | 79311550224813 | Assets.Furniture | Hull | -90X |  |
| FUR_Fridge.fbx | 133735701322271 | Assets.Furniture | Hull | -90X |  |
| FUR_Vase_Frac.fbx | 95834630886815 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_Lamp_Frac.fbx | 118296352663490 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_TV_Frac.fbx | 139537262344758 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| TRK_Pickup_Body.fbx | 94970103150551 | Assets.Trucks | Hull (CanCollide=false, visual only) | -90X | rig parts stay as collision |
| TRK_Pickup_Wheel.fbx | 129396673512851 | Assets.Trucks | Hull | -90X |  |
| FUR_Piano.fbx | 128849773732698 | Assets.Furniture | Hull | -90X |  |
| FUR_Aquarium.fbx | 74019265278554 | Assets.Furniture | Hull | -90X |  |
| FUR_GrandfatherClock.fbx | 106572731956036 | Assets.Furniture | Hull | -90X |  |
| FUR_Bookshelf.fbx | 83521917526069 | Assets.Furniture | Hull | -90X |  |
| FUR_Microwave.fbx | 77281682806502 | Assets.Furniture | Hull | -90X |  |
| FUR_PottedPlant.fbx | 112246883820998 | Assets.Furniture | Hull | -90X |  |
| FUR_Mirror.fbx | 100237847405569 | Assets.Furniture | Hull | -90X |  |
| FUR_Piano_Frac.fbx | 94513744736043 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_Aquarium_Frac.fbx | 132807304200489 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_GrandfatherClock_Frac.fbx | 81533731078157 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_Bookshelf_Frac.fbx | 140712692053458 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_Microwave_Frac.fbx | 130011931181464 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_PottedPlant_Frac.fbx | 112050751094420 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_Mirror_Frac.fbx | 91459625207203 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_Couch_Frac.fbx | 123719792249686 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_CardboardBox_Frac.fbx | 137958496927011 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_Chair_Frac.fbx | 90116175097027 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_Mattress_Frac.fbx | 110156000261400 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| FUR_Fridge_Frac.fbx | 75090120419562 | Assets.Fractured | Box | -90X | 4-6 chunks, client-only debris |
| PRP_Dolly.fbx | 91411744849292 | Assets.Props | Hull | -90X | upgrade prop |
| PRP_Strap.fbx | 128836483436146 | Assets.Props | Box | -90X | upgrade prop |
| PRP_LoadingRamp.fbx | 110020955733950 | Assets.Props | Hull | -90X | upgrade prop |
| TRK_BoxTruck_Body.fbx | 108570079110448 | Assets.Trucks | Hull (CanCollide=false, visual only) | -90X | rig parts stay as collision |
| PRP_Tree.fbx | 135748336439958 | Assets.Props | Box | clean | decoration: anchored, CanCollide/CanTouch/CanQuery off |
| PRP_HQSign.fbx | 86889511556582 | Assets.Props | Box | clean | decoration: anchored, CanCollide/CanTouch/CanQuery off |
| PRP_GarageDoor.fbx | 81765704927874 | Assets.Props | Box | clean | decoration: anchored, CanCollide/CanTouch/CanQuery off |
| PRP_Shelving.fbx | 130963158080792 | Assets.Props | Box | clean | decoration: anchored, CanCollide/CanTouch/CanQuery off |
| PRP_CrewPadBoard.fbx | 76608789397576 | Assets.Props | Box | clean | decoration: anchored, CanCollide/CanTouch/CanQuery off |
| PRP_Mailbox.fbx | 125516749650402 | Assets.Props | Box | clean | decoration: anchored, CanCollide/CanTouch/CanQuery off |
| PRP_Bin.fbx | 127270058469386 | Assets.Props | Box | clean | decoration: anchored, CanCollide/CanTouch/CanQuery off |
| PRP_Streetlight.fbx | 108682382255837 | Assets.Props | Box | clean | decoration: anchored, CanCollide/CanTouch/CanQuery off |
| PRP_Fence.fbx | 98325690922816 | Assets.Props | Box | clean | decoration: anchored, CanCollide/CanTouch/CanQuery off |
| COS_HardHat.fbx | 117361836869359 | Assets.Props | Box | clean | hat; add Handle/HatAttachment |
| COS_HardHatGold.fbx | 138662877759792 | Assets.Props | Box | clean | hat; add Handle/HatAttachment |
| COS_TruckerCap.fbx | 93858528570073 | Assets.Props | Box | clean | hat; add Handle/HatAttachment |
| COS_Beanie.fbx | 73223630436678 | Assets.Props | Box | clean | hat; add Handle/HatAttachment |
