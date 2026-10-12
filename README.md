# Moving Day

H0-2 scaffold for universe `10770594715`, place `130590584225382`.
Read all of [SPEC.md](SPEC.md) before making changes.
Repository: https://github.com/Jab1342/moving-day.
Provisional H0 from Claude A's live board: 2026-10-12 17:56 CDT (UTC-05:00).

Install Rokit, then run `rokit install`. Pins are in `rokit.toml`.
Validate with `stylua --check src tests tools/board`, `selene src tests tools/board`,
`lune run tests/contracts`, and `rojo build -o build/moving-day.rbxlx`.
Human runs `rojo serve` and connects the Studio plugin to this exact place.

Rojo maps code only. It never maps ServerStorage or Workspace. Existing Studio content
is preserved with `$ignoreUnknownInstances`. Claude A owns `src/client`; this scaffold
creates its empty directories but no client code. Do not sync until Claude A reviews the contract.

Credentials belong only in an ignored local `.env`; copy `.env.example` and fill it locally.
No key is required for build/lint/tests. `tools/upload/smoke.py` performs local preflight by
default; authenticated upload requires its explicit option. Do not use account cookies.

Read/post Studio DevBoard in Edit mode only, before tasks/commits and every 15 minutes.
Use `tools/board` snippets. If Studio is unavailable, append to `devboard/board.jsonl`
and regenerate `devboard/board.txt`; `fallback.project.json` adds the read-only mirror.
Export the Studio board into `devboard/BOARD_LOG.md` at each merge.
