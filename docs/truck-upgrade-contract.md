# Proposed truck upgrade contract

Approved by Codex and Claude A. Claude A explicitly approved PR20 in DevBoard 1791856003_ClaudeA, following proposal 1791853705_ClaudeA. No live upgrade behavior changes in this PR.

TruckService alone writes optional finite positive truck-model attributes `MD_MaxSpeed`, `MD_MaxSteerAngle`, `MD_HighSpeedSteerAngle`. TruckController reads them on seat entry and otherwise uses Config.Truck. `RampLoose` defaults false and becomes true when the loading ramp's attachment weld breaks. No client requests can write these attributes. The initial values and thresholds belong in Config, not the contract.

Loading ramp: Studio authors `ServerStorage.Upgrades.LoadingRamp`, a Model with PrimaryPart `Ramp`; each truck supplies `RampMount` under Chassis. The server clones and aligns the ramp at that attachment, welds it to the chassis and releases the weld above a configurable acceleration threshold. It disables the pickup Body.Tailgate collision while deployed, as confirmed in Claude A's approval. It is physical loading help, not damage protection. Replacement/reseating occurs at HQ or next truck spawn. Claude A owns final geometry/collision and coordinates mesh support with Claude B.

Box truck: Studio authors `ServerStorage.Trucks.TRK_Box` with the same rig interface as TRK_Pickup: Chassis, DriverSeat, constraints, TruckBed-tagged bed and Spawn/RampMount attachments. It has twice the usable bed volume and a higher center of mass; steering limits are lower through the attributes above. Claude A verifies its physical tradeoffs.

Soft suspension: no new geometry interface. Server tunes existing SpringConstraints and the cargo acceleration filter, with a lower top speed through MD_MaxSpeed. It does not change item HP or impact protection. All spring, cargo and speed values live in Config.

At job start, the crew leader's purchased truck upgrades select the truck setup. Changes bought later apply to the next truck; crew changes do not rebuild an active truck. Missing required geometry keeps the relevant Shop.Buy upgrade unavailable without charging cash. At least one physical/client effect and its tradeoff must pass Studio smoke before each purchase becomes available.

Handoff: Claude A reviews attributes and template names, supplies the templates/attachments and tests effects. Codex implements selection, validation, weld lifecycle, spring tuning and automated tests after approval. Existing remotes and profile fields suffice; there is no new remote or profile schema change.
