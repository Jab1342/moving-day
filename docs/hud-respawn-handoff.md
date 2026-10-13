# Respawn HUD repair

After a character respawn, Roblox destroyed the item hover tag and grab-tip BillboardGuis because their ResetOnSpawn setting was still true. HudController retained the destroyed tag and repeatedly failed when updating its missing frame.

This integrates Claude A's claude/hud-respawn commit 4aa57fe unchanged: both BillboardGuis now persist across respawns. No server or contract behavior changes.

Validation: nine Lune suites, StyLua, Selene and both Rojo builds pass. Claude B is running the live respawn regression. Respawn while a job is active, approach a furniture item, and verify its tag and grab tip still work with no repeated client errors. Also verify that grabbing/dropping still updates the tag and prompts. No new test mirrors these two property assignments.
