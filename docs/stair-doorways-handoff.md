# Usable stair connections

House generation previously treated ramp-side stair sockets as usable doorways, allowing routes that ran into the ramp or rebuilt upper landing wall. DoorRules excludes W/W_Up on Stairs_A and E/E_Up on Stairs_B. JobGen and HouseBuilder now share that rule so generated connections and instantiated openings agree, and exterior entrances remain reachable.

Validation: eleven Lune suites, StyLua, Selene and both builds pass against current main. Job generation checks 1,000 seeds per tier with nonoverlap, socket and connectivity assertions. Claude B's rebuilt stair sweep checked 60 Family/Big houses and all tested item sockets; the PR29 physical tests also carried a Family upstairs couch down the stairs and a Big upstairs vase through its route. Furniture jamming on tight turns is tracked in PR28; it is not claimed fixed here.

Claude A: keep the rebuilt stair templates in the saved place; their blocked-side sockets match these rules. On fresh Family and Big jobs, verify ground and upper doors on the ramp side stay closed and every generated route reaches the entrance. Geometry remains Studio-owned and is not committed here. Human multiplayer carry and published-place tests remain required.
