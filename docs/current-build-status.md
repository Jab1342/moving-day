# Current build handoff

H0 remains provisional October 12, 2026 at 17:56 America/Chicago. Continue the existing development heartbeat, stop at H0+48h or when the human ends the build. Codex uses Studio MCP only for the board and never writes during Play.

## Repository state

Main is 44ff0b7. This work session merged PR25 lost-root cleanup, PR14 ping relay, PR17 physically verified dolly purchases, PR18 receipt foundation, PR15 analytics, PR34 respawn HUD repair and PR21 stair doorway rules. Earlier uploaded strap/recover animations and approved purchase contracts are also on main.

PR36 (codex/integration-followups) is the next combined Studio candidate. It includes pending physics/truck upgrades, guarded purchase/pass benefits, server item-hit ragdolls, parked-truck ownership repair, cash-pack analytics, Claude A carry through ce9b75f, strap/recover readers and the opt-in Studio mock profile fixture. Sixteen Lune suites, seven Python uploader tests, StyLua/Selene and both Rojo builds pass. The old PR29 branch stays frozen at b363f0d; do not serve it by mistake for follow-up fixes.

## Next priorities

- Claude A must serve/test PR36 after the current Studio lock ends. Rojo reconnected per board1791862386. The live handoff is board1791862663; docs/integration-followups-handoff.md has the ordered checks.
- Ramp never-deploy repair is PR33, included in PR36. PR38 adds the isolated mock UpgradeShop profile so tests can buy ramp/box/soft upgrades. Confirm actual deploy, walking/loading, stow/drive/exit, and ramp breakaway before enabling the physical upgrades on main.
- Cargo's loose weld breaks under hard stop, but actual out-of-bed spill still needs a pass. Keep PR11/26/29/36 gated.
- Latest carry ce9b75f: B2602 reports zero drops, both stairs fixed and clean output; two doorway stalls clear with one back-up. A owns push/trail transition and ordinary constraint lag slowing the player. Keep Config synchronized with the author's next branch. Do not edit client code directly.
- A requested a dolly-damage decision. Current carried impact threshold is 28 studs/s of velocity change, so sub-8 stud/s contacts already cannot damage. Board1791862665 asks for previous/current server velocity, state/Dolly, HP and fixture/drop timing after the target fixes. B notes a two-stud pre-grab fixture drop; do not hide real impacts with broad immunity.
- PR32 ragdoll needs live bounded-contact, alive/recovery/respawn validation, especially client Neck/RequiresNeck handling. PR30 purchase guards need clean first-session/payout smoke with empty IDs, then mock entitlement/prompt tests. Real purchases/rejoin/dashboard remain human/account-dependent.
- PR31 contract for physical LeadGrip mapping still requires Claude A approval. Do not implement or merge it prematurely. Nav-beacon review request1791859531 remains for A: fallback pivot, first-grab gating and Config tunables. StoreController remains on claude/store-ui, unavailable SKUs stay hidden.
- Insurance/CrewBoost durable context and remaining VIP/Horn/Radio effects are stubs and unavailable. Product API authorization failed earlier; human Creator Hub setup is the existing fallback. Do not invent IDs or create paid effects from prompt completion.

## Art and release

PR37 codex/game-icon-draft contains assets/images/ICON_GameDraft_v1.png (1254 square), its complete built-in imagegen prompt and Open Cloud upload/registry records. Image asset83033014562407 is a draft and has not been applied to the experience. Review against current game art at launch; real thumbnails/video still require gameplay captures. Do not use staged crew poses as multiplayer proof. Homeowner NPC/animations and extra furniture remain outside v1 scope pending human expansion.

Human still owns real two/four-client gates, published rejoin/purchases, phone FPS, account requirements and publishing. Never print, log or commit .env. Use append-only repo board while Play prevents live posts. Primary checkout/user changes stay untouched; active Codex worktree is C:/Users/jettg/.codex/worktrees/client-handoff/Moving Day.
