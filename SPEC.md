# Moving Day — 48-Hour Build Spec

Verbatim text extracted from the user-supplied 32-page PDF; table reading order follows PDF extraction. Source PDF is authoritative for layout and figures.

## Source page 1

Moving Day — 48-Hour Build Spec (Codex +
Claude)
Oct 12, 2026  ·  @jack
Mission and definition of done
Ship Moving Day v1 to Roblox in 48 hours: a 1–4 player co-op game where a crew carries
fragile furniture out of a house, loads a wobbly truck, drives it across town and gets paid
for whatever survives. Codex and Claude build in parallel against one shared contract
(section 5); the human owner handles account, publishing and multi-client playtests.
The game is done at hour 48 when all of these are true on a published place:
How to read this doc. Sections 4–6 are the spec; section 5 is law — change it only through
the protocol in section 2. Section 8 is the clock. Section 11 is how agents talk to each other
live, and section 12 lists what never to do. Anything not listed in section 4 is out of scope
for v1 and goes on the post-launch list in section 10.
A new player is holding furniture within 60 seconds of spawning, with no menu in the
way.
1 player can carry small items; 2 players can carry a couch or piano together; a solo
player can move 2-person items with the free dolly.
The truck drives on PC, mobile and gamepad; cargo rides in the bed and spills only
when driven badly.
Items take damage from impacts, visibly break into pieces, and lose value.
A full job runs end to end in 8–15 minutes: house → truck → drive → destination →
itemised payout screen naming who broke what.
Cash buys at least 5 upgrades at HQ; progress saves and survives rejoin.
Up to 4 crews of 4 share one 16-player server without interfering.
Ping wheel works without chat or voice.
3 game passes and 3 developer products work; analytics funnel events fire.
Runs at 30+ FPS on a mid-range phone during a 4-player job.
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 1 of 32

## Source page 2

Agent roles and rules of engagement
Split by what each agent can touch: Codex works only in the git repo, Claude drives
Roblox Studio and Blender through their MCP connections, and the human does anything
that needs the Roblox account or more than one real client.
Agent Owns Tools Never touches
Codex All server and shared
Luau: services, data,
economy, jobs, damage
math, payout, crews,
monetization, analytics,
anti-exploit; unit tests for
every pure module.
Every upload except
Blender models:
generates and uploads all
images (UI icons, ping
icons, decals, game icon,
thumbnail compositions),
creates game passes and
developer products,
uploads animations and
audio (even ones Claude
made), and keeps the
asset ID registry.
Git repo, Rojo, Lune,
StyLua, Selene, Open
Cloud APIs, image
generation, Roblox
Studio MCP (message
board only)
Studio geometry,
Blender, UI layout
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 2 of 32

## Source page 3

Agent Owns Tools Never touches
Claude A
(Studio)
Everything that needs
feel-tuning in Studio:
carry controller, truck
chassis, house room
templates, HQ and town
map, UI layout, VFX/SFX,
controls on mobile and
gamepad, solo playtests.
Client Luau for those
systems. Authors
animations and hands
the files to Codex to
upload. Inserts uploaded
models into Studio by
asset ID.
Roblox Studio MCP, git
repo
Server services
Codex owns (reads
them, posts
requests); any upload
Claude B
(Blender)
Every 3D mesh: furniture,
fracture sets, truck
bodies, HQ props,
cosmetics. Uploads its
own models straight
from Blender and
registers each asset ID.
Renders reference art for
Codex's game icon.
Blender MCP, Roblox
Blender add-on (or
Open Cloud from
Blender's Python),
assets/  folder
Luau code; uploads of
anything that isn't a
Blender model
Human Account and money:
creates the Open Cloud
API key and logs the
Roblox Blender add-on
in; ID verification,
maturity questionnaire,
Kids/Select setup;
connects Codex and
both Claudes to the
Studio MCP; runs rojo
serve ; clicks Publish in
Studio; runs every 2- and
4-player test; buys ads.
Roblox Creator Hub,
Studio
Never pastes keys
into chat, the board,
the repo or this doc
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 3 of 32

## Source page 4

Rules both AIs follow:
1 . The contract is law. src/shared/Contracts/  (section 5) is written by Codex in hour
0–2 and reviewed by Claude A before anyone builds on it. After that, a change needs a
PR titled contract:  that both agents approve and a Contract  post on the message
board; nobody edits contract files inside a feature PR.
2. One owner per folder (section 3). To change a folder you don't own, post a Request  on
the board with the exact change; don't edit it.
3. Talk on the board, live. Every agent reads the Studio message board (section 11) before
starting each task, before every commit, and at least every 15 minutes while working,
and answers anything addressed to it before starting new work.
4. Branches: codex/<feature>  and claude/<feature> . Small PRs into main , merged at
least every 3 hours. main  must always load in Studio without errors.
5. Handoff note on every PR: what changed, how to test it in Studio, what's stubbed,
what the other agent must do next. Put it in the PR body and post it on the board as
Done .
6. Stubs over waiting. If you need something the other agent hasn't shipped, code
against the contract with a stub marked -- STUB(owner):  and keep going. Never
block.
7. Rojo owns code, Studio owns geometry. Never edit a Rojo-synced script inside Studio
— it will be overwritten. Never commit place geometry as Luau.
8. Uploads go through their owner. Claude B uploads Blender models; Codex uploads
everything else. Every uploaded asset is registered in assets/registry.json  before
anyone uses its ID.
9. No new dependencies or services beyond those in section 3 without a contract:  PR.
1 0. Sync points (section 8) are hard stops: merge, run the gate test, fix what fails before
starting new work.
1 1 . Tunable numbers live in Config , never hard-coded, so the human can balance without
touching logic.
1 2. Read the do-nots (section 12) before your first task.
Repo layout and toolchain
One git repo synced into Studio with Rojo; game logic that needs no Roblox APIs lives in
Logic/  so Codex can test it outside Studio with Lune.
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 4 of 32

## Source page 5

Tools (pinned with Rokit in rokit.toml ): Rojo 7, StyLua, Selene, Lune. No Wally packages
in v1. Format with StyLua and lint with Selene before every PR.
moving-day/
  default.project.json        Rojo mapping (Codex)
  rokit.toml  stylua.toml  selene.toml
  .env                        Open Cloud API key + universe/place IDs (human; 
gitignored, never committed)
  .gitignore                  must list .env
  src/
    shared/                   -> ReplicatedStorage.Shared
      Contracts/              Remotes, Attributes, Types, Enums (Codex 
writes, both approve)
      Config.luau             every tunable number (Codex)
      ItemDefs.luau           furniture catalogue data (Codex)
      UpgradeDefs.luau        upgrade data (Codex)
      AssetIds.luau           generated from assets/registry.json (Codex)
      ProductIds.luau         pass and product IDs (Codex)
      Logic/                  pure functions, no Roblox APIs (Codex)
        DamageModel.luau  Payout.luau  Economy.luau  JobGen.luau
    server/                   -> ServerScriptService.Server (Codex)
      Services/  DataService  CrewService  JobService  ItemService
                 TruckService  DamageService  PayoutService  UpgradeService
                 MonetizationService  AnalyticsService  AntiExploitService
      Vendor/    ProfileStore
      init.server.luau
    client/                   -> StarterPlayer.StarterPlayerScripts.Client 
(Claude A)
      Controllers/  CarryController  TruckController  PingController
                    CameraController  InputController  VfxController
      UI/           Hud  PayoutScreen  Shop  CrewBoard  PingWheel  Settings
      init.client.luau
  tests/                      Lune specs for src/shared/Logic (Codex)
  tools/
    upload/                   Open Cloud upload scripts: images, audio, 
animations, passes, products, thumbnails (Codex)
    board/                    message board read/post snippets and the log 
exporter (Codex)
  assets/
    registry.json             every uploaded asset: name, type, assetId, 
uploadedBy, file (Codex and Claude B append)
    blend/  export/  renders/ Blender sources, FBX exports, reference renders 
(Claude B)
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 5 of 32

## Source page 6

    images/                   generated images before upload (Codex)
    anim/                     animation files from Claude A awaiting upload
    audio/                    sound files awaiting upload
  devboard/
    BOARD_LOG.md              board exported at every merge (Codex)
Studio-owned content (not in Rojo, saved in the place file): Workspace.Map  (town, roads,
HQ), ServerStorage.RoomTemplates , ServerStorage.Trucks ,
ReplicatedStorage.Assets  (meshes inserted by asset ID, fracture sets, VFX, sounds),
and ServerStorage.DevBoard  (the message board, section 11). Claude A owns all of it
except the board, which every agent writes to. Rojo must never map ServerStorage , or it
will wipe the board. The human saves the place to Roblox after each sync point.
Game spec (v1 scope)
The whole game is one loop that takes 8–15 minutes, built so failure is funny and costs
money but never ends the job. All numbers below are starting values and live in Config  or
ItemDefs .
Design pillars (if a feature fights one of these, cut the feature):
1 . Hands on furniture in 60 seconds. No menus, no tutorial screens; teach with prompts
in the world.
2. Damage costs money, never the job. A job always pays something.
3. Two people beat one. Big items need two carriers, or one carrier with a slow dolly.
4. Upgrades add options, not safety. Every upgrade trades one risk for another; total
damage protection is capped at 50% ( Config.MaxProtection ).
5. Works with no voice or chat. Everything a crew needs to say goes through the ping
wheel.
Core loop
1 . Form a crew at HQ: step on one of 4 crew pads (1–4 players). Roblox party members
are put on the same pad automatically ( Player.PartyId ). Solo starts instantly; a crew
auto-starts 20 s after the second player joins, or when the leader presses Start.
2. Drive to the job. The crew spawns its truck at the HQ dock; the job house is on one of 4
lots around town, one crew per lot.
3. Clear the house. The manifest lists every item. Carry items out, load them into the
truck bed, strap them down.
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 6 of 32

## Source page 7

4. Drive to the new house (600–900 studs). Hard braking, sharp turns and bumps can
shift or spill cargo that isn't strapped.
5. Unload into the destination house. An item counts once it's inside the destination
footprint.
6. Payout screen: every item listed with value kept or lost and who broke it; star rating;
cash and XP split equally among crew members present.
7. Back at HQ: spend cash on upgrades, then the next job. The payout screen previews
the next job to pull players into "one more".
First session. A player with no save skips HQ: they spawn with their party straight into a
Starter job (studio apartment, 6 items including one couch). World prompts teach grab →
carry → load → strap → drive → unload. First payout lands at about 4 minutes, then they
arrive at HQ with enough cash for their first upgrade.
Jobs
The timer is soft: running over reduces the time bonus to zero but never fails the job.
Houses are assembled from room templates (section 6), so no two jobs are identical.
Furniture (v1 catalogue)
Tier House Items Timer Unlocks
at
Starter Studio apartment, 2–3
rooms
6 6 min Level 1
Family
Home
4–5 rooms, one staircase 12 10
min
Level 3
Big House 6–7 rooms, 2 floors 18, always a piano or
aquarium
14
min
Level 6
Item Carry Value ($) Fragility Clip moment
Cardboard box 1 player 20 0.5 —
Chair 1 player 30 0.6 —
Potted plant 1 player 25 0.8 Soil spray
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 7 of 32

## Source page 8

Every item has 100 HP. Fragility multiplies impact damage (section 6). An item at 0 HP
breaks into pieces and is worth $0.
Upgrades (sold at HQ)
Item Carry Value ($) Fragility Clip moment
Lamp 1 player 40 1.5 Bulb pop
Microwave 1 player 60 1.0 Ding on impact
Vase 1 player 80 2.5 Shatter
Mirror 1 player 120 3.0 Shatter
TV 1 player 150 2.0 Screen crack
Mattress 2 players 90 0.2 Bounces
Bookshelf 2 players 110 0.7 —
Couch 2 players 200 0.4 —
Fridge 2 players 250 0.8 Door swings open
Grandfather clock 2 players 350 1.8 Chime on impact
Aquarium 2 players 400 2.5 Water splash, fish flop
Piano 2 players 600 1.2 Chord on every bump
Upgrade Gives Costs you Price ($)
Dolly (free for solo) One player moves a 2-person
item
40% walk speed
while using it
0 / speed tiers
300, 900
Straps +2 tie-down slots per level;
strapped cargo won't shift
2 s to strap each
item
250 / 600 /
1,200
Moving blankets Wrapped item takes 30%
less damage
$10 per use, 3 s to
wrap
400 unlock
Loading ramp Faster loading Ramp can be
knocked loose
500
Box truck Bed 2× bigger Top-heavy, slower
turning
2,000
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 8 of 32

## Source page 9

Crews, solo and griefing
Solo: free dolly; 2-person items move at 40% speed; payout scales to crew size so solo
is fair.
Carry priority: the first player to grab an item owns it; a second player can only take
the second grip of a 2-person item.
No player-vs-player damage. Players can bump and ragdoll each other only through
items.
Blame: a break is charged to the last player who carried the item, or to the driver if it
broke in the truck. It shows on the payout screen only; it costs nobody anything extra.
Crew leader can remove a member from the crew (not from the server).
Shared servers in v1: crews share one 16-player server on separate lots. Teleports to
reserved servers can't be tested in Studio and would eat build time; friends still count
as co-play when they join through Roblox parties and invites. Private crew servers ship
in week 4.
Assist mode (settings): items 50% sturdier, payout −20%.
Ping wheel
8 pings, each shows above the player's head with an icon and plays a voice line: Lift!,
Drop!, Stop!, Go!, Pivot left, Pivot right, Over here, Nice! Two-person lifts get an
automatic 3-2-1 countdown when both grips are taken.
Controls
Upgrade Gives Costs you Price ($)
Soft suspension Less bounce in the bed Lower top speed 1,500
Cosmetics (paint,
horn, hats)
Style Cash sink 150–1,000
Action PC Gamepad Mobile
Grab / drop E X Grab button
Rotate held
item
R Y Rotate button
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 9 of 32

## Source page 10

UI screens
Hud  (job timer, manifest count, cash), item hover tag (name, value, HP bar), PingWheel ,
PayoutScreen , Shop  (HQ upgrades), CrewBoard  (pad status, Start button), Settings
(Assist mode, camera, volume). All UI built with UIScale  for phone screens; touch targets
at least 44 px.
Interface contracts
This is the shared API: Codex commits it as src/shared/Contracts/  in hour 0–2, Claude
A approves it, and after that it changes only through a contract:  PR. Every client
request is validated on the server; the client never decides damage, money or ownership.
Remotes
All remotes live in ReplicatedStorage.Shared.Remotes , created by the server at startup
from Contracts/Remotes.luau .
Action PC Gamepad Mobile
Strap / wrap F B Strap button
Ping wheel G (hold) D-pad up Ping button
Drive WASD, Space =
handbrake
Triggers + left
stick
Thumbstick + gas/brake
buttons
Horn H L3 Horn button
Name Kind Direction Payload Server checks
Carry.RequestGrab RemoteFunction client →
server
itemUid:
string, grip: 1
| 2  → ok,
reason?
Same crew,
within 8 studs,
grip free, item
not Broken
Carry.RequestDrop RemoteEvent client →
server
itemUid Caller is a
carrier
Carry.SecondGrip UnreliableRemoteEvent client →
server, 20
Hz
itemUid,
handPos:
Vector3
Caller holds grip
2; relayed to the
lead carrier
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 10 of 32

## Source page 11

Name Kind Direction Payload Server checks
Carry.SecondGripRelay UnreliableRemoteEvent server →
lead
client
itemUid,
userId, handPos
—
Carry.RequestStrap RemoteFunction client →
server
itemUid,
action: "Strap"
| "Wrap"  → ok,
reason?
Item in own
truck bed
(Strap) or held
(Wrap); slots
and cash
Ping.Send RemoteEvent client →
server
pingId: number,
worldPos:
Vector3?
Rate limit 2 per
second
Ping.Broadcast RemoteEvent server →
crew
userId, pingId,
worldPos?
—
Crew.Action RemoteFunction client →
server
action: "Join"
| "Leave" |
"Start" |
"Kick", arg?  →
ok, reason?
Pad capacity,
leader-only
actions
Crew.State RemoteEvent server →
client
CrewState —
Job.State RemoteEvent server →
crew
JobState —
Job.ItemEvent RemoteEvent server →
crew
itemUid, kind:
"Damaged" |
"Broken" |
"Loaded" |
"Delivered", hp:
number
—
Job.Payout RemoteEvent server →
crew
PayoutReport —
Shop.Buy RemoteFunction client →
server
upgradeId, tier
→ ok, reason?
At HQ, price,
prerequisites
Data.Profile RemoteEvent server →
client
PublicProfile —
Settings.Set RemoteEvent client →
server
key, value Whitelisted
keys only
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 11 of 32

## Source page 12

Instance attributes
The client reads attributes for UI and VFX; only the services named above write them.
Types ( Contracts/Types.luau)
export type ItemState = "Idle" | "Carried" | "InTruck" | "Delivered" | 
"Broken"
export type CarryMode = "One" | "Two"
export type Tier = "Starter" | "Family" | "Big"
export type ItemDef = {
id: string, displayName: string, carry: CarryMode,
value: number, fragility: number, massScale: number,
model: string,      -- name in ReplicatedStorage.Assets.Furniture
fractured: string,  -- name in ReplicatedStorage.Assets.Fractured
impactSound: string?,
}
On Attribute Type Written by
Furniture
model
ItemId , ItemUid ,
CrewId
string ItemService
Furniture
model
HP number 0–100 DamageService
Furniture
model
State ItemState ItemService
Furniture
model
CarrierA , CarrierB userId, 0 = none ItemService
Furniture
model
BlameUserId userId DamageService
Furniture
model
Strapped , Wrapped boolean ItemService
Truck model CrewId , DriverUserId string, userId TruckService
Player CrewId , Level ,
Assist
string, number,
boolean
CrewService,
DataService
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 12 of 32

## Source page 13

export type JobState = {
jobId: string, crewId: string, tier: Tier, lotId: number,
phase: "Loading" | "Driving" | "Unloading" | "Payout",
startedAt: number, softEndsAt: number,
manifest: { [string]: ItemState },  -- itemUid -> state
}
export type PayoutLine = {
itemUid: string, itemId: string,
valueKept: number, valueLost: number, blameUserId: number?,
}
export type PayoutReport = {
jobId: string, lines: { PayoutLine },
jobFee: number, timeBonus: number, total: number,
perPlayer: number, xpEach: number, stars: number,  -- 1..5
nextJob: { tier: Tier, lotId: number },
}
export type Profile = {
version: number, cash: number, xp: number, level: number,
upgrades: { [string]: number },     -- upgradeId -> tier
cosmetics: { [string]: boolean },
catalog: { [string]: boolean },     -- itemIds delivered intact at 
least once
stats: { jobs: number, delivered: number, broken: number, moneyLost: 
number },
streak: { lastDay: number, count: number },
settings: { assist: boolean },
firstJobDone: boolean,
purchases: { [string]: boolean },   -- processed receipt ids
}
Pure logic API ( Shared/Logic, unit-tested in Lune)
DamageModel.impactDamage(deltaV: number, def: ItemDef, mods: { protection: 
number, assist: boolean }): number
Payout.compute(result: JobResult, crewSize: number): PayoutReport
Economy.levelForXp(xp: number): number
Economy.upgradePrice(upgradeId: string, tier: number): number
JobGen.generate(seed: number, tier: Tier): HouseLayout  -- room templates + 
item sockets, deterministic per seed
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 13 of 32

## Source page 14

Config ( Shared/Config.luau, starting values)
return {
DamageThreshold = 14,        -- studs/s of velocity change before 
damage starts
DamagePerStudPerSec = 6,     -- HP lost per stud/s above threshold, 
times fragility
GrabGraceSeconds = 0.75,     -- no damage right after grab, load or 
unload
MaxDeltaVAccepted = 120,     -- larger readings are treated as 
exploit noise
MaxProtection = 0.5,         -- cap on all damage reduction combined
GrabRange = 8,
DollySpeedScale = 0.4,
BedSettleSeconds = 1.0,      -- cargo still for this long gets welded 
to the bed
BedBreakG = 2.2,             -- unstrapped weld breaks above this 
acceleration (g)
StrappedBreakG = 4.5,
SoloPayoutScale = 1.0, CrewPayoutScale = { 1.0, 1.15, 1.25, 1.35 },
AssistDamageScale = 0.5, AssistPayoutScale = 0.8,
JobFee = { Starter = 150, Family = 400, Big = 900 },
SoftTimer = { Starter = 360, Family = 600, Big = 840 },
TimeBonusMax = 0.25,         -- share of item value at 0 s overtime
CrewAutoStartSeconds = 20,
MaxCrews = 4, MaxCrewSize = 4,
}
Saving: vendor ProfileStore as a single ModuleScript in src/server/Vendor/  for session-
locked profiles (store Profiles_v1 , key u_<userId> ). Developer product receipts are
recorded in Profile.purchases  before granting, so ProcessReceipt  is idempotent.
Technical architecture
Use Roblox's standard network-ownership model, with the server deciding ownership,
damage and money; do not turn on Server Authority mode in v1 (player-vs-player contact
mispredicts and mobile correction cost is unproven). Write carry and truck logic as pure
step functions so a later move to Server Authority is possible.
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 14 of 32

## Source page 15

Each row is one system: the client asks through a remote in the contract, and the server
service on the right decides; payout and job state flow the other way.
Carry (one player)
1 . Client presses Grab → Carry.RequestGrab .
2. Server checks range and crew, sets CarrierA , calls SetNetworkOwner(player)  on the
item first, then creates and enables an AlignPosition  + AlignOrientation  (single-
attachment mode) targeting a point in front of the player's chest. Enabling the
constraint before ownership is set causes about 0.6 s of lag and rubber-banding.
3. The carrier's client moves the constraint target every frame. Use moderate MaxForce
and Responsiveness  (start at Responsiveness 25) and put the item in a Carried
collision group that ignores its carrier, or the item flings the player.
4. Drop: server disables constraints, sets CarrierA = 0 , starts the grab grace window,
and returns ownership to automatic.
System architecture · client, remotes, server
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 15 of 32

## Source page 16

Two-person carry
Only one machine can simulate an object, so the first grabber (grip 1) is the lead and
owns the item. The second player (grip 2) sends their hand position over
Carry.SecondGrip  at 20 Hz; the server relays it to the lead; the lead's client drives the
item toward the midpoint of both grips and orients it along the line between them. The
server enforces a leash: grip 2 is slowed past 6 studs from its grip point and auto-drops
past 10. Both players' hands follow the item with IK so it looks shared. If the lead drops,
grip 2 becomes the lead and ownership transfers.
Solo dolly: an item on a dolly is carried by one player as a 1-player item with walk speed
scaled by Config.DollySpeedScale .
Truck and cargo
Start from the official Racing template's constraint chassis, re-bodied with Claude B's
truck mesh. Fewest springs that still bounce visibly.
When a player sits in the VehicleSeat , the server sets that driver as network owner of
the truck and of every loose item in the bed. On exit, ownership returns to automatic.
Bed welding: cargo that has been still relative to the bed for BedSettleSeconds  is
welded to the bed, so it rides as part of the truck assembly at no extra physics cost.
The server breaks the weld when bed acceleration exceeds BedBreakG  (unstrapped)
or StrappedBreakG  (strapped), or when the truck tilts past 35°. Broken welds make
cargo loose again so it can slide and spill.
Bed floor and cargo use high-friction CustomPhysicalProperties ; furniture collision
fidelity is Hull.
Mobile and gamepad driving go through the Input Action System so one binding set
works everywhere.
Breakage
Do not use .Touched  for damage: it misses hits, fires on sliding, and the owning client
controls it.
DamageService samples each active item's AssemblyLinearVelocity  every
Heartbeat on the server. A sudden drop in speed is an impact: damage = max(0, Δv −
DamageThreshold) × DamagePerStudPerSec × fragility × (1 − protection) .
Clamp Δ v at MaxDeltaVAccepted .
No damage during the grace window after grab, load or unload; a 0.3 s per-item
cooldown between damage events.
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 16 of 32

## Source page 17

At 0 HP: server sets State = "Broken"  and destroys the item; each client spawns the
item's pre-fractured model ( ItemDef.fractured ) locally at that position, applies a
small burst impulse, and removes the pieces after 6 s. Pieces never replicate.
Player ragdoll: when a moving item hits a player above a speed threshold, the server
fires a ragdoll to that player's client, which swaps Motor6D s for
BallSocketConstraint s for 2 s.
Anti-exploit
Ownership of every furniture item is set explicitly, never left to automatic while it's
carried or in a truck.
AntiExploitService checks every carried item each server tick: distance from the
carrier's hands (max 10 studs), linear speed (max 80 studs/s while carried), and
displacement per tick. On a violation it calls SetNetworkOwner(nil) , restores the last
valid CFrame, and logs a strike; 5 strikes in a minute drops the player from the crew.
Rate-limit every remote (token bucket per player). Reject NaN and infinite vectors.
Procedural houses
ServerStorage.RoomTemplates  holds 12 room models built by Claude A (kitchen,
bedroom, bathroom, living room, hallway, stairs; 2 variants each). Each has door
sockets (Attachments named Door_N/E/S/W ) and item sockets (Attachments named
Item_<size> ).
JobGen.generate(seed, tier)  picks rooms, connects them by matching door
sockets on a 24-stud grid, rejects overlaps by bounding box, and assigns manifest
items to sockets by size. Same seed, same house.
Houses are anchored; furniture is spawned unanchored only when the job starts and
destroyed when it ends.
Performance budget
Budget Limit
Awake unanchored assemblies per server 150
Furniture items per job 18
Parts per room template 300
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 17 of 32

## Source page 18

Enable StreamingEnabled  with StreamOutBehavior = Opportunistic ; make each
house and each truck an Atomic model. Turn off CanCollide , CanTouch  and CanQuery
on decoration.
Art and Blender pipeline
Claude B owns every mesh through the Blender MCP; nobody waits on art, because
Claude A builds a Part-based graybox of each item in Studio first and swaps in the mesh
when it lands.
Style: low-poly, flat-shaded, bright and readable from a phone camera. Every mesh shares
one 512 px palette texture ( assets/blend/palette.png , a grid of colour swatches); UVs
are snapped onto swatches, so there is no per-asset texturing.
Rules for every mesh
Scale: model in studs. Before anything else, export a 4 × 1 × 2 reference cube; the
human imports it and confirms its Size in Studio reads 4, 1, 2. Fix the Blender unit scale
until it does, then lock it for every file.
Orientation and pivot: front of the item faces Blender −Y; origin at the bottom centre;
apply all transforms before export.
Budgets: furniture 1,500 triangles, hero items (piano, aquarium, clock) 4,000, truck
8,000, fracture chunk 300.
Naming: FUR_<Item>  for furniture, FUR_<Item>_Frac  for its fractured set,
TRK_<Truck>_Body , TRK_<Truck>_Wheel , PRP_<Prop> , COS_<Cosmetic> . Names must
match ItemDefs.model  and ItemDefs.fractured .
Fracture sets: use the Cell Fracture extension (or manual cuts) to make 4–6 large
chunks per item, each a separate object, exported together as one FBX. No tiny shards.
Budget Limit
Furniture mesh 1,500 triangles (hero items 4,000)
Truck mesh 8,000 triangles
Texture size 512 px, one shared palette atlas
Client frame rate on a mid-range phone, 4-player
job
30 FPS minimum
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 18 of 32

## Source page 19

Export: FBX to assets/export/ , one file per asset, plus a line in
assets/export/MANIFEST.md : file, target folder in Studio, collision fidelity (Box for
small items, Hull for furniture and trucks).
Grip points are not modelled. Claude A adds Grip1  / Grip2  attachments in Studio.
Upload and import path
Models go from Blender to Roblox without the human:
1 . Claude B uploads each finished model straight from Blender with the Roblox Blender
add-on (the human logs it in once at hour 0). Fallback: a Blender Python script calling
the Open Cloud Assets API with the key from .env .
2. Claude B registers it: appends { name, type: "Model", assetId, uploadedBy:
"ClaudeB", file }  to assets/registry.json  and posts Done  on the board listing
the names.
3. Codex regenerates AssetIds.luau  from the registry.
4. Claude A inserts each model into Studio by asset ID through the Studio MCP, moves it
into Assets.Furniture , Assets.Fractured , Assets.Trucks  or Assets.Props , sets
collision fidelity, adds grip attachments, replaces the graybox and posts Done .
New uploads can wait in moderation for a while, so upload in batches early rather than one
big batch at a gate. If an upload or insert fails, Claude B exports the FBX to
assets/export/  and posts a Blocker ; the human imports that file with Studio's 3D
Importer.
Asset list
Due Assets
Hour 10 (P0) Couch, cardboard box, chair, lamp, vase, TV,
mattress, fridge; pickup truck body and wheel;
fracture sets for vase, lamp, TV
Hour 20 (P1) Piano, aquarium, grandfather clock, bookshelf,
microwave, potted plant, mirror; fracture sets for
all remaining items; dolly, strap, loading ramp; box
truck
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 19 of 32

## Source page 20

Thumbnails start as in-game captures by Claude A; Codex crops, composes and uploads
them, never replacing gameplay with generated scenes, because Roblox reduces
exposure for thumbnails that don't match gameplay. Codex generates the game icon from
Claude B's reference render.
48-hour schedule
Four lanes run in parallel from hour 2, and every lane stops at each gate until the gate test
passes; G1 at hour 10 is the make-or-break test, because if two players can't carry a couch
into a truck nothing else matters.
Hours 0–2 (shaded) are setup in every lane. The human works at the gates: save the place,
run the gate test with real clients, and post failures on the board as Blocker s. Uploads
run continuously in the Codex and Claude B lanes, not at gates.
Due Assets
Hour 34 (P2) HQ props (sign, garage door, shelving, crew-pad
board), town props (mailbox, bin, tree, streetlight,
fence), 3 cosmetic hats; reference render of the
crew and truck for Codex's game icon
48-hour build plan · 4 lanes, 4 gates
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 20 of 32

## Source page 21

Gates
If a gate fails, all lanes stop new work and fix it. If G1 still fails at hour 12, Codex joins
Claude A on carry networking until it passes.
Tasks by lane
Codex
Gate Hour Passes when Run by
Contract 2 Contracts merged; place loads with
graybox furniture; reference cube
uploaded from Blender reads 4 × 1 × 2 in
Studio; every agent has posted on the
board
Claude A +
human
G1 Couch test 10 2 players carry the couch into the truck
and drive 200 studs; strapped it survives a
hard stop, unstrapped it spills
Human, 2
clients
G2 Full job 20 A Starter job runs end to end with payout
and one upgrade bought; progress
survives rejoin
Human, 2
clients
G3 Freeze 34 Every v1 feature is in; passes and products
work; no new features after this
All
G4 Release
candidate
44 Every acceptance test in section 10 passes Human, 4
clients
Launch 48 Published public with the launch checklist
done
Human
H0–2: repo, Rojo project, Rokit tools, Contracts/ , Config , ItemDefs , UpgradeDefs ;
open the contract:  PR; create ServerStorage.DevBoard  and the board snippets;
test every Open Cloud endpoint
H2–10: Logic/  modules with Lune tests; DataService (ProfileStore); ItemService
(spawn, attributes, grab/drop checks, ownership); DamageService; generate and
upload ping and UI icons
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 21 of 32

## Source page 22

Claude A (Studio)
Claude B (Blender)
Human
H10–20: JobGen; JobService (phases, manifest, lots, delivery detection);
PayoutService; CrewService (pads, parties, leader); UpgradeService and Shop.Buy ;
TruckService (spawn per crew, driver ownership, bed weld and unweld); upload Claude
A's sounds and animations as they land
H20–34: create passes and products; MonetizationService with idempotent
ProcessReceipt ; analytics wrapper and funnel; ping relay; AntiExploitService; Assist
mode; first-session flow (new players spawn into a Starter job)
H34–48: fix posted bugs; balance pass in Config ; DamageService cost check with 150
active items; game icon, thumbnails and video uploads; tag the release
H0–2: place folders, streaming settings, collision groups; Part graybox of all 15 items
with Grip1 / Grip2 ; review the contract PR
H2–10: CarryController (one player, two players, IK hands, dolly); truck from the Racing
template; a test track with bumps and a hard-stop zone; insert P0 models by asset ID
as Claude B posts them
H10–20: 12 room templates with door and item sockets; town with HQ, roads and 4 lots;
HUD, item hover tag, PayoutScreen, CrewBoard, Shop; author carry, strap and ragdoll-
recover animations and hand the files to Codex in assets/anim/
H20–34: InputController for PC, gamepad and touch; PingWheel; onboarding prompts;
VFX and SFX (shatter, splash, piano chord); HQ build; insert P1 models
H34–48: solo playtests, mobile performance pass, polish, insert P2 models, capture raw
thumbnail shots for Codex
H0–2: palette texture; upload the reference cube from Blender and confirm its size
with Claude A
H2–10: P0 models (section 7), each uploaded and registered as soon as it's done
H10–20: P1 models and every fracture set, uploaded and registered
H20–34: P2 models; reference render for the game icon
H34–48: fixes from Claude A's board posts, re-uploaded as new versions
H0: account steps in section 9; create the experience; make the API key; log in the
Blender add-on; connect all three agents to the Studio MCP; run rojo serve
Every gate: save the place, run the gate test with real clients, post failures on the board
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 22 of 32

## Source page 23

Cut list
If a lane is behind at any gate, cut in this order:
1 . Aquarium water and fish physics (keep a splash effect)
2. Big House tier (ship Starter and Family Home)
3. Box truck and soft suspension upgrades
4. Grandfather clock, bookshelf and mirror
5. Horn & Radio pack
6. Player ragdoll on hit
Never cut: carry, two-person carry, dolly, truck and cargo, breakage, payout screen with
blame, ping wheel, mobile controls, saving, onboarding funnel.
Analytics, monetization and launch readiness
v1 ships with the onboarding funnel instrumented and 6 fixed-price items for sale; Codex
does every upload, the human does only identity, policy, publishing and money; nothing
for sale is random and nothing for sale makes furniture harder to break.
Analytics (Codex, AnalyticsService wrapper)
Onboarding funnel ( LogOnboardingFunnelStepEvent ), once per player: 1 Spawned · 2
First grab · 3 First item loaded · 4 First drive · 5 First item delivered · 6 First payout · 7
First upgrade bought · 8 Second job started. Steps 1–4 decide the bounce signals
Roblox ranks on; they must all land inside 3 minutes.
Economy events: cash sources (job payout, Crew Boost, cash packs) and sinks
(upgrades, blankets, cosmetics).
Custom events: JobCompleted  (tier, stars, crew size, seconds), ItemBroken  (itemId),
PingUsed  (pingId), InsuranceOffered  / InsuranceBought .
Any time: answer board posts addressed to Human  within 30 minutes while awake
H24: Roblox group; Discord
H42–48: description and genre, publish from Studio, launch ads
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 23 of 32

## Source page 24

Monetization v1 (Codex wires MonetizationService; Codex also creates every
pass and product through Open Cloud and writes the IDs to
Shared/ProductIds.luau)
Turn on Managed (regional) pricing for all of them. Subscription, paid private servers and
rewarded video come after launch (section 10).
Launch readiness (human)
Start the slow items on hour 0; some take days to clear.
Item Type Price
(Robux)
What it does
VIP Foreman Game pass 249 Gold hard hat, +10% tips, VIP tag on
crew pad
2x Pay Game pass 399 Doubles your cash from jobs
Horn & Radio
pack
Game pass 99 6 truck horns and an in-truck radio
Insurance
Claim
Developer
product
19 Offered on the payout screen when
$100+ was lost; refunds the lost value
of that job, once per job
Crew Boost Developer
product
79 2x pay for the whole crew for 30
minutes
Cash packs Developer
product
49 / 149 /
399
$500 / $1,800 / $5,500
Human, hour 0: ID verification and 2-step verification on the publishing account
Human, hour 0: Kids/Select requirements started (Plus for 2 months or the refundable
per-game fee). Without this, new games are shown only to age-checked players 16+
Human, hour 0: Maturity & Compliance questionnaire, targeting Minimal or Mild
Human, hour 0: experience created; Studio API access on; Open Cloud API key created
with only the scopes Codex needs (asset upload, game passes, developer products,
thumbnails) and saved in .env ; Roblox Blender add-on logged in; Studio MCP
connected for Codex, Claude A and Claude B
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 24 of 32

## Source page 25

Acceptance tests and roadmap
A build ships only when every test below passes on the published place; the human runs
the multi-player ones, the AIs run the rest.
Automated (Codex, Lune, run on every PR)
Solo playtest (Claude A, Studio Play mode)
Codex, hour 0–2: test-upload one image and one dry-run product through each Open
Cloud endpoint; post results on the board. Any upload type the API refuses goes to the
human, by Creator Hub, for the rest of the build
Codex, hour 24: all passes and products created; IDs in ProductIds.luau
Human, hour 24: Roblox group and Discord
Codex, hour 44: 3–5 thumbnails composed from Claude A's captures and uploaded;
thumbnail personalization on
Codex, hour 44: game icon generated from Claude B's render and uploaded
Codex, hour 44: 30-second gameplay video uploaded (real gameplay, no voiceover, no
music with lyrics); human uploads it if the API can't
Human, hour 44: description and genre set; title stays "Moving Day"
Human, hour 48: Publish from Studio; set public; small Ads Manager "Plays" campaign
plus an "Engagement" campaign to reach the 250 qualifying plays
Codex + human, hour 72: referral rewards (needs the game live for 1 day) and
Experience Notification templates for "your crew is online" and "daily contract ready"
DamageModel : no damage below threshold; damage scales with fragility; protection
never exceeds MaxProtection ; Δ v above MaxDeltaVAccepted  is clamped.
Payout : a job with every item broken still pays the job fee; per-player shares sum to
the total; stars match the intact-value bands.
Economy : level curve is monotonic; every upgrade tier has a price.
JobGen : same seed gives the same house; no overlapping rooms across 1,000 seeds;
every manifest item has a socket.
New profile: holding an item within 60 s, first payout within 5 min.
Dolly moves a couch; truck drives on keyboard, emulated gamepad and emulated
phone.
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 25 of 32

## Source page 26

Multiplayer (human, 2 and 4 clients)
After launch: first 8 weeks (weekly update every Saturday)
Strapped cargo survives a 40 studs/s hard stop; unstrapped cargo spills from the same
stop.
Vase dropped from chest height breaks; box dropped from chest height doesn't.
Rejoin restores cash, level and upgrades.
Every pass and product works in Studio test purchases.
Two players carry a couch up and down stairs without jitter that makes it unplayable.
Lead carrier leaves mid-carry: grip 2 takes over without the item flinging.
4 crews run jobs at once on one server; no crew can grab another crew's items.
Payout names the right player for each break.
Ping wheel works with chat disabled.
30 FPS on a real mid-range phone during a 4-player Big House job.
Week Update
1 Bug fixes from launch, second neighbourhood,
daily contracts and 7-day streak
2 Furniture Catalogue collection book, "Fewest
Breaks" weekly leaderboard
3 HQ decorating, offline dispatcher income (up to 8
hours)
4 Persistent crews (shared company level and HQ) in
private reserved servers, Union Card subscription,
paid private servers
5 Hillside town with steep roads, limited truck paint,
Earthquake Move admin event
6 Office moves for 4-player crews, rewarded video
for Insurance Claim (once eligible)
7 Haunted Mansion limited event (furniture moves
on its own)
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 26 of 32

## Source page 27

Each week, check bounce under 60 s and 61–180 s, D1, play days on days 2–7 and 8–28, co-
play days and spend days in Creator Analytics, and aim the next update at the weakest
one.
Live message board (inside Studio)
All agents talk through one board that lives in the open Studio place at
ServerStorage.DevBoard ; each agent reads and posts to it through the Roblox Studio
MCP, and the human can read it in Studio's Explorer at any time.
Setup (hour 0). The human connects Codex, Claude A and Claude B to the same running
Studio through the Roblox Studio MCP. Codex creates the DevBoard  folder with a pinned
_README  message holding the rules below. Rojo must never map ServerStorage .
Message format
Each message is a StringValue  in ServerStorage.DevBoard , named <unix
time>_<from> , with the text in Value  and these attributes:
Protocol
1 . Read the board before each task, before every commit and at least every 15 minutes;
handle anything Open  addressed to you or All  before new work.
Week Update
8 Season 1 pass (cosmetic track), payout replays,
Hardcore mode for streamers
Attribute Values
From Codex , ClaudeA , ClaudeB , Human
To All  or one agent name
Type Info , Request , Blocker , Done , Contract
Status Open , Ack , Resolved
Ref Optional: PR number, file path or asset name
ReplyTo Optional: name of the message being answered
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 27 of 32

## Source page 28

2. Acknowledge a Request  or Blocker  by setting its Status  to Ack  and posting a reply
with ReplyTo ; set Resolved  when it's done.
3. Blockers come first. A Blocker  stops the receiving agent's current task until it's
acknowledged.
4. Post Done  for every merged PR, every upload batch (with asset names) and every gate
result.
5. Post Contract  for every contract change, linking the contract:  PR.
6. Keep it short: one topic per message, under 500 characters; details go in the PR or
issue named in Ref .
7. Never post during a Play test. Changes made in Play mode are thrown away when the
test stops.
8. Never delete or edit someone else's message other than setting its Status .
9. Persistence: the board survives only when the place is saved, so the human saves at
every gate, and Codex exports the board to devboard/BOARD_LOG.md  at every merge.
Snippets (run with the Studio MCP's Luau tool, in Edit mode)
Post a message:
local board = game:GetService("ServerStorage"):WaitForChild("DevBoard")
local msg = Instance.new("StringValue")
msg.Name = `{os.time()}_Codex`
msg.Value = "ItemService merged (PR 12). Grab/drop live; strap is stubbed."
msg:SetAttribute("From", "Codex")
msg:SetAttribute("To", "ClaudeA")
msg:SetAttribute("Type", "Done")
msg:SetAttribute("Status", "Open")
msg:SetAttribute("Ref", "PR 12")
msg.Parent = board
Read open messages for one agent:
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 28 of 32

## Source page 29

local me = "Codex"
local out = {}
for _, m in game:GetService("ServerStorage").DevBoard:GetChildren() do
local to = m:GetAttribute("To")
if m:IsA("StringValue") and m:GetAttribute("Status") ~= "Resolved" 
and (to == "All" or to == me) then
table.insert(out, `{m.Name} | {m:GetAttribute("From")} | 
{m:GetAttribute("Type")} | {m:GetAttribute("Status")} | {m.Value}`)
end
end
table.sort(out)
return table.concat(out, "\n")
Acknowledge or resolve: board["<message name>"]:SetAttribute("Status", "Ack") .
Fallback. If the Studio MCP accepts only one agent at a time, the board moves to
devboard/board.jsonl  in the repo (same fields, one message per line, append-only).
Codex regenerates a readable copy, devboard/board.txt , on every post; Rojo syncs that
.txt  into Studio as the StringValue  ReplicatedStorage.DevBoardMirror , so the
human can still read the board in Studio. Codex checks this at hour 0 and posts which
mode is live.
Do-nots
Every agent reads this list before its first task; breaking one of these is a bug, even if the
feature works.
UI (Claude A builds, Codex generates the images)
Don't show any UI before a new player's first grab: no splash screen, no daily-reward
popup, no shop popup on join.
Don't open a full-screen panel during a job; only the payout screen may take the full
screen.
Don't show more than one purchase prompt per job, and never one the player didn't
trigger, except the Insurance Claim offer on the payout screen.
Don't use offset-only sizing. Use Scale, AnchorPoint  and UIScale ; check every
screen on a small phone, a tablet and a 1080p desktop in Studio's device emulator.
Don't place UI over Roblox's own controls: keep clear of the top bar, the top-left menu,
the mobile thumbstick (bottom-left) and the jump button (bottom-right).
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 29 of 32

## Source page 30

Don't use text smaller than 14 px on a phone or touch targets smaller than 44 px.
Don't bake words into images. Every word on screen is a TextLabel  so it can be read
and translated.
Don't use colour as the only signal (damage, item state, ping type); pair it with an icon
or a word.
Don't use emoji in UI text, more than 2 fonts, or ResetOnSpawn = true  on UI that
should persist.
Don't add fake buttons, "like the game" nags, timers that pressure purchases, or
anything that looks like an ad.
Don't build gameplay UI that needs reading during a carry; the HUD shows at most the
timer, item count and cash.
Models (Claude B)
Don't exceed the triangle budgets in section 7, or use any texture other than the
shared 512 px palette.
Don't put real brands, logos, trademarks or readable text on any model or texture (no
real furniture stores, car makers or TV brands).
Don't export with unapplied transforms, a pivot anywhere but the bottom centre, or a
scale that hasn't passed the reference-cube check.
Don't make fracture sets with more than 6 chunks or tiny shards.
Don't model grip points, collision proxies or welds; Claude A adds those in Studio.
Don't rename an asset after uploading it; IDs are looked up by name.
Don't upload the same model twice. Check assets/registry.json  first; a fix is a new
version of the same asset.
Don't use Precise collision fidelity on anything.
Code (Codex and Claude A)
Don't use .Touched  for damage, wait() , spawn()  or delay()  (use task  functions),
deprecated body movers ( BodyVelocity , BodyGyro , BodyPosition ), loadstring , or
global variables.
Don't let the client decide money, damage, ownership, item state or purchases. The
client asks; the server checks and decides.
Don't call InvokeClient ; server-to-client is RemoteEvents only.
Don't insert free models or Toolbox scripts.
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 30 of 32

## Source page 31

Don't hard-code a number that belongs in Config , or an asset or product ID that
belongs in AssetIds  / ProductIds .
Don't yield inside ProcessReceipt  except for the profile save, and never grant a
product before recording the receipt.
Don't write while true do  loops without task.wait , or connect per-frame work for
objects that aren't active in a job.
Don't edit Rojo-synced scripts inside Studio.
Physics (Claude A and Codex)
Don't weld carried furniture to a character.
Don't enable a carry constraint before ownership is set, or call SetNetworkOwner  on
anchored parts.
Don't turn on Server Authority mode in v1.
Don't leave furniture ownership on automatic while it's carried or in a truck.
Don't simulate decoration: anchor it and turn off CanCollide , CanTouch  and
CanQuery .
Don't let anything fling a player: cap constraint force and clamp item speeds.
Uploads and secrets
Don't put the API key anywhere but .env : not in the repo, the board, the doc, chat,
logs or a commit message.
Don't upload anything without adding it to assets/registry.json  in the same step.
Don't upload generated images that imitate a real person, brand or another game's
characters.
Don't change a pass or product price after launch without the human's OK.
Monetization and policy
Don't sell random items, loot boxes or paid rolls.
Don't sell anything that makes furniture harder to break or carry faster than free
players can.
Don't reward players for likes, favorites or group joins with gameplay items; group
perks are cosmetic only.
Don't build anything that needs voice or text chat to play.
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 31 of 32

## Source page 32

Don't use thumbnails, icons or video that show things the game doesn't have.
Communication and repo
Don't change a contract file without a contract:  PR and a Contract  post.
Don't edit a folder you don't own; post a Request .
Don't delete or rewrite another agent's board message.
Don't merge to main  with Studio errors, failing Lune tests, or unformatted code.
Don't wait silently: if you're blocked, post a Blocker  and switch to a stub.
Moving Day — 48-Hour Build Spec (Codex + Claude)
Page 32 of 32