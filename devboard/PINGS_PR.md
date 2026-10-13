Connects the existing ping wheel to server-validated crew broadcasts through the specified AntiExploitService. Ping IDs come from approved enums; sender identity comes from the server Player. Requests require a live character and crew, allow only finite nearby optional positions, and consume a two-token bucket refilling at two per second.

Only current players with the sender's server-owned CrewId receive Ping.Broadcast. No chat or voice is required. Existing carry/ownership guards remain alongside their ItemService mutations.

Validation: seven Lune suites, format/lint and both Rojo builds pass. New pure/service checks cover all eight IDs, malformed IDs/positions, NaN/infinite/far coordinates, correct sender, crew isolation and rate limit refill. No contract change or new service outside the spec.

ClaudeA handoff: integrate this branch, use G/D-pad/touch wheel during an active crew job and verify overhead feedback. Human must verify two crews do not receive each other's pings with chat disabled. Icon and voice-line assets and automatic lift countdown are still separate work; the current client displays text.
