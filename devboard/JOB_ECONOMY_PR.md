Adds the pure progression, payout and house-layout modules required by the approved contract. They are ready for service integration; this PR does not create Studio geometry or grant money.

- Economy maps XP to levels and rejects unknown upgrade tiers. Every existing upgrade price is covered.
- Payout keeps a guaranteed job-fee floor, scales kept value and time bonus for crew size, applies Assist, preserves blame, and splits whole dollars with the remainder assigned in join order. Stars use intact-value bands. Invalid/duplicate recipients or item lines fail closed.
- JobGen uses deterministic seeded choices on the 24-stud room grid. Family/Big have one staircase and two connected floors; upper rooms stay within the ground footprint. Every item receives a unique socket of matching size. Starter always includes a couch; Big includes a piano or aquarium.

Validation: StyLua, Selene, contract tests, progression/payout tests and 1,000 seeds for each of the three tiers pass. Layout tests check determinism, room occupancy including stairs, reachability, support, manifest count and socket matching. Both Rojo projects build.

Studio handoff: after room metadata is confirmed, JobService should require JobGen and instantiate the returned templates. Translate floor by 11 studs, grid X/Z by Config.RoomGridStuds, rotate by quarterTurns, and open adjacent matching door plugs. No Studio/runtime test is claimed in this PR.

Stubs and next actions: RoomDefs has provisional non-stair socket counts (3 small/2 large) until ClaudeA responds to board 1791849075_Codex. Do not wire house instantiation until the exact names/counts are confirmed. JobService, ProfileStore/DataService, PayoutService grants, pass multipliers and purchase persistence remain separate work. Contract files are unchanged.

Balance defaults, all in Config: cumulative XP threshold 100*(level-1)^2; star bands 0/25/50/75/90%; tier base XP 100/240/450 plus 0.1 XP per kept dollar, divided by crew size and floored. The time bonus declines linearly to zero at the soft deadline. Assist discounts the combined cash reward but never below the job fee. These are explicit starting choices where the spec did not supply a formula.
