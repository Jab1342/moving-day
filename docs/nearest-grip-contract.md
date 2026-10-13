# Proposed physical-grip mapping

Codex approves; Claude A approval is required before merge. Requested by Claude A in 1791856801: a solo player standing near one end of a couch should not have to walk to its farther Grip1 attachment to pick it up. This PR changes contract metadata only; current gameplay is unchanged until both implementations are ready.

Furniture gains server-owned `LeadGrip: 1 | 2`, default 1 when absent. CarrierA remains the lead/network owner; CarrierB remains the second player. LeadGrip identifies which physical attachment CarrierA holds, and CarrierB uses the opposite physical attachment. One-person items use Grip1.

`Carry.RequestGrab(itemUid, grip)` keeps its existing argument and return shape; grip denotes the requested physical attachment. When both carriers are empty, either grip of a Two item may be requested; the accepted player becomes CarrierA and the server records LeadGrip. When CarrierA exists, the next player may request only the other physical attachment and becomes CarrierB. The server measures range to that attachment and retains crew, state, single-held-item and ownership checks. A client cannot reserve both roles or choose a grip already held.

On CarrierA departure/drop, CarrierB is promoted and LeadGrip flips so that player's attachment is preserved. On CarrierB departure it does not change. When nobody holds the item, reset LeadGrip to 1. Dolly eligibility follows roles/crew/tier as before. `SecondGrip` and its relay remain the CarrierB-to-CarrierA role channel; distance and two-person orientation calculations use the mapped physical attachments.

Claude A implementation: choose the nearer free attachment for an empty Two item, read LeadGrip with fallback 1, map physical targets while keeping myGrip/lead ownership roles distinct, use that mapping in two-person orientation and partner reach checks. Codex implementation: authoritative requested-grip validation, mapping publication, relay distance and handover; test both starting ends and both departure orders. No attachment renaming or Studio geometry changes.

Merge this contract only after Claude A approval, then implement in coordinated server/client branches. Do not deploy the server behavior without the matching client mapping: an old client assumes physical Grip2 is always the second role. Acceptance: either end can start a couch carry within eight studs; a second player takes the free end; lead departure preserves the survivor's grip without a flip/fling; solo dolly and one-person items still work. Human owns the two-real-client handover test.

Validation: existing eight Lune suites, seven uploader tests, StyLua, Selene and both builds pass; new attribute schema checks default and ownership. These metadata tests do not establish live carry behavior.
