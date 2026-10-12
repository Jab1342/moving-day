# contract: establish Moving Day H0 shared API and scaffold

Moving Day has no shared code or remote schema. This change provides the H0 contract,
all 15 furniture definitions, six upgrade definitions, central tuning, and pinned tooling.
Server startup creates the specified remotes and returns `(false, "NotReady")` for
unimplemented functions. Events have no gameplay handlers yet.

Validation: pinned StyLua and Selene, Lune contract checks, and both normal/fallback
Rojo builds. Live Studio gameplay load is still Claude A/human's H2 gate, not claimed here.
Image smoke upload passed and is registered as H0_UploadProbe; product read returned
HTTP 403. Product payload passed local dry-run only; no documented API dry-run exists.

Review status: **Approved by Claude A once additions A-E are applied; all are included.**
Approval evidence: DevBoard `1791846685_ClaudeA`, `1791846686_ClaudeA`,
and `1791846961_ClaudeA`. Codex accepts the changes. Studio runtime gate remains pending.
Provisional H0 from Claude A's board: 2026-10-12 17:56 CDT (UTC-05:00).

Claude A review decisions:

- Dot names mean folders (`Shared.Remotes.Carry.RequestGrab`), with positional arguments.
- `CrewState`, `PublicProfile`, `JobResult`, and `HouseLayout` are proposed because the
  PDF names them without defining them. PublicProfile excludes receipt history.
- `Crew.Action` Join argument is pad number; Kick is userId; Leave/Start omit it.
  Times use server time (`Workspace:GetServerTimeNow()`); timestamps are seconds.
- Ping IDs 1-8 follow the listed spec order. `Settings.Set` currently permits `assist`
  boolean only; camera/volume remain client-local pending a contract proposal.
- `Job.ItemEvent` adds `info: ItemEventInfo?` with itemId, CFrame and velocity,
  required on Damaged/Broken before destruction. `Fx.Ragdoll` sends duration and impulse.
- `Dolly` is an ItemService boolean attribute. `Contracts/Carry` names the attachment
  and OneAttachment constraints; ownership is assigned before enabling them, and
  CarrierB is promoted to CarrierA when the lead drops.
- `PayoutReport.shares` is keyed by tostring(userId). `perPlayer=floor(total/crewSize)`;
  remainder goes +1 to earliest-joined recipients. `JobResult.memberUserIds` provides
  those eligible recipients in join order to the unchanged compute(result, crewSize) API.
- `Config.Truck` contains the seven steering, speed, torque and radius values reviewed by Claude A.
- The spec says 3 developer products but lists Insurance, Crew Boost and 3 cash packs
  (5 IDs). No production products are created in H0.
- Item IDs match Claude A's graybox post: `box`, `chair`, `plant`, `lamp`, `microwave`,
  `vase`, `mirror`, `tv`, `mattress`, `bookshelf`, `couch`, `fridge`, `clock`, `aquarium`,
  `piano`. Model names match Claude A's confirmed mapping; fracture suffix is `_Frac`.
  `massScale=1` is an explicit initial stub. Sounds are absent.

How to test in Studio after approval: human starts Rojo, connects to place
130590584225382, confirms the diff contains only code, then starts Play. Verify 16
remotes under Shared.Remotes and four RemoteFunctions return false/NotReady.
Confirm Workspace, ReplicatedStorage.Assets and ServerStorage.DevBoard remain intact.
Stop Play before posting to the board. Human saves the place after the H2 gate.

Next: Claude A supplies client/geometry work and verifies Studio runtime with the human.
Human confirms kickoff and saves the Studio place at the H2 gate.
