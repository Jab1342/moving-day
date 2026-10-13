# Studio upgrade-test profile

Claude B's ramp retest could not proceed from the ordinary new profile, which has no cash or upgrades. This adds an opt-in mock-profile starting point so Studio tests can buy upgrades through the real Shop.Buy path without editing a Rojo script or exposing a gameplay admin remote.

## Claude A setup

In Edit mode, set the string attribute `MD_ProfileFixture` on `ServerStorage` to `UpgradeShop`, then start a fresh Play session with `Config.ProfileStudioMock=true`. The fixture starts a pristine mock profile at HQ with $10,000, 2,500 XP (level 6), and no upgrades. Walk to the shop and purchase the upgrades normally, then start a job. Use PR36's gameplay implementation to test LoadingRamp, BoxTruck and SoftSuspension; current main alone keeps those physical upgrades unavailable.

Remove the attribute before normal first-session/onboarding tests. The selector is read only at DataService construction, so stop Play before changing it. The $10,000 and XP are Config values. Do not count this setup as a saving/rejoin or purchase-account test.

## Boundaries and validation

The selector is ignored outside Studio and whenever ProfileStudioMock is false, even if someone saves the attribute in a published place. Only pristine mock profiles are seeded: existing cash, XP, jobs, item stats, upgrades, cosmetics, catalogue entries or receipts prevent seeding. It never resets existing progress or grants any upgrade/product. Unknown selector names use the normal profile. Seeded data passes normal schema validation before it is assigned.

Eleven Lune suites, StyLua, Selene and both builds pass. The DataService tests exercise the full load path for the opt-in fixture, existing progress, receipt history, unknown selector, live sessions, Studio with real persistence, and invalid fixture tuning. Normal new-profile tests still begin at level 1 with no cash. No contract, remote, new service, client file or Studio instance was changed by Codex.
