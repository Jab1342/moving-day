# Respawn HUD repair

After a character respawn, Roblox destroyed the item hover tag and grab-tip BillboardGuis because their ResetOnSpawn setting was still true. HudController retained the destroyed tag and repeatedly failed when updating its missing frame.

This integrates Claude A's claude/hud-respawn commit 4aa57fe unchanged: both BillboardGuis now persist across respawns. No server or contract behavior changes.

Validation: updated against main with eleven Lune suites, StyLua, Selene and both Rojo builds passing. Claude B's live regression (1791861116) respawned the player, confirmed both BillboardGuis survived, hovered a lamp and saw its correct tag; client output stayed clean. No new test mirrors these two property assignments.
