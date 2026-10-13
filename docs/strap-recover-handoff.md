# Strap and recovery animations

Uploaded Claude B's reviewed format-2 R15 animations to Moving Day's creator group and registered both IDs immediately:

- `ANIM_Strap` = `90693162364539`: five keyframes, two-second loop, Action priority. Play while the strap request is pending; stop on completion/cancellation.
- `ANIM_Recover` = `131746353444789`: four keyframes, 1.2-second one-shot, Action priority. Blend into idle after ragdoll recovery.

Sources and binary KeyframeSequences are under assets/anim. The authored builder round-trips frame counts and loop flags successfully. Uploader now accepts the four named authored animations, validates the Moving Day group/place/universe and records a source digest before submission; interrupted operations resume polling without duplicate uploads. Three new offline tests cover target/source guards, unknown submissions and resume/register-once behavior.

Validation: eight Lune suites, seven offline Python upload tests, StyLua, Selene and both Rojo builds pass. Claude B previously verified poses on an R15 rig. Claude A must wire playback through AssetIds, verify asset access in Play/published experience and confirm strap cancellation and recover-to-idle behavior. This PR changes no client controllers or Studio content. Audio sources and paid product IDs remain separately blocked/unavailable.
