# Upgrade and scenery asset integration

Imports Claude B's eight uploaded props and corresponding Blender/FBX sources from `claude/p0-models` at 4bab6f7: PRP_DoorInsert, PRP_DoorFrameOpen, PRP_WindowInsert, PRP_YardSign, PRP_TrafficCone, PRP_Pallet, PRP_RampWedge and PRP_RampRails. AssetIds is regenerated; all 71 existing registry entries are preserved, for 79 total. No uploads are repeated.

Also imports the taller TRK_BoxTruck_Body source/export and its upload-version journal under the existing asset ID. Claude B reports the Studio box truck has twice the bed length, increased center of mass and an opening that fits the fridge/clock upright, with road driving tested. The loading ramp's high-end pivot aligns to Chassis.RampMount; the pickup tailgate needs collision disabled while deployed. Details are in DevBoard 1791855486–1791855488.

No ItemDefs changes: the seven extra office/neighborhood furniture models remain on Claude B's branch for later scope. This integration does not activate truck purchases or touch Studio geometry. Server upgrade effects await contract PR20 approval and implementation. The asset uploader's separate version-update code remains on the author branch pending review; its completed version journal is retained here.

Validation: every registry name is unique, every ID is numeric, every referenced file exists, and imported binary sources match the author's branch. Run the normal Luau/build checks and offline audio uploader tests. Claude A/B verify the inserted geometry and texture in Studio; Codex implements the approved server effects separately.
