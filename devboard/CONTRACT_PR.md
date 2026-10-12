# contract: establish Moving Day H0 shared API and scaffold

Moving Day has no shared code or remote schema. This change provides the H0 contract,
all 15 furniture definitions, six upgrade definitions, central tuning, and pinned tooling.
Server startup creates the specified remotes and returns `(false, "NotReady")` for
unimplemented functions. Events have no gameplay handlers yet.

Validation: pinned StyLua and Selene, Lune contract checks, and both normal/fallback
Rojo builds. Live Studio gameplay load is still Claude A/human's H2 gate, not claimed here.
Image smoke upload passed and is registered as H0_UploadProbe; product read returned
HTTP 403. Product payload passed local dry-run only; no documented API dry-run exists.

Review status: **DRAFT, not approved or merged.**
Provisional H0 from Claude A's board: 2026-10-12 17:56 CDT (UTC-05:00).

Claude A review decisions:

- Dot names mean folders (`Shared.Remotes.Carry.RequestGrab`), with positional arguments.
- `CrewState`, `PublicProfile`, `JobResult`, and `HouseLayout` are proposed because the
  PDF names them without defining them. PublicProfile excludes receipt history.
- `Crew.Action` Join argument is pad number; Kick is userId; Leave/Start omit it.
  Times use server time (`Workspace:GetServerTimeNow()`); timestamps are seconds.
- Ping IDs 1-8 follow the listed spec order. `Settings.Set` currently permits `assist`
  boolean only; camera/volume remain client-local pending a contract proposal.
- `Job.ItemEvent` lacks break position/model data after the server destroys an item.
  Preserve the PDF payload for now; Claude A should propose how VFX caches this data.
- `PayoutReport.perPlayer` is a single number but rounding must preserve total shares.
  Agree a rounding policy before H2 Payout implementation.
- The spec says 3 developer products but lists Insurance, Crew Boost and 3 cash packs
  (5 IDs). No production products are created in H0.
- Item IDs match Claude A's graybox post: `box`, `chair`, `plant`, `lamp`, `microwave`,
  `vase`, `mirror`, `tv`, `mattress`, `bookshelf`, `couch`, `fridge`, `clock`, `aquarium`,
  `piano`. Case-sensitive model names remain proposed pending Claude A's exact mapping;
  fracture suffix is `_Frac`. `massScale=1` is an explicit initial stub. Sounds are absent.

How to test in Studio after approval: human starts Rojo, connects to place
130590584225382, confirms the diff contains only code, then starts Play. Verify 15
remotes under Shared.Remotes and four RemoteFunctions return false/NotReady.
Confirm Workspace, ReplicatedStorage.Assets and ServerStorage.DevBoard remain intact.
Stop Play before posting to the board. Human saves the place after the H2 gate.

Next: Claude A reviews this contract and supplies client/geometry work. Codex records
approval before merging. Human confirms kickoff and saves the Studio place at the H2 gate.
