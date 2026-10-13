# Truck steering, seat exit and dolly placement

Integrates Claude A's claude/truck-feel commits through 493ef46 without editing their client code. Codex adds the corresponding tunables to Config so they can be balanced centrally. Dolly heading now follows walking direction at 120 degrees/second. Claude B still reproduced a wall-jam/leash drop at a tight upstairs turn (1791859098); Claude A owns that remaining collision/soft-leash tuning, so this remains a pending playtest gate.

Steering servo response and straight-line correction reduce drift when driving without input. Jump remains locked at speed and while a jump is held through stopping, then restores on exit. Dolly loads sit centered ahead of the player with their long side along the route, a 1.1-stud deck and quarter-turn rotation. Grab prechecks use the same grip attachment range as the current server.

Claude A measured approximately 0.4 degrees drift / 2.1 studs lateral motion over 187 studs for steering, and verified a centered couch (0.3 studs lateral, 5 ahead). Claude B verified the earlier truck steering and ramp carry. Final held-Space-through-stop and current dolly regression smoke remain requested before merge. The server's ability to choose the nearer initial physical grip is a separate contract proposal; it is not implemented here.

Validation: existing eight Lune suites, seven offline upload tests, StyLua, Selene and both Rojo builds pass. Claude A: verify current branch on keyboard/gamepad/mobile, hold Space through a full stop, release then exit, re-enter repeatedly and respawn; check jump settings restore. Carry/rotate a couch through a door and up/down the rebuilt stairs without unexpected sideways offset. Human still owns two-real-client carry and rejoin gates.
