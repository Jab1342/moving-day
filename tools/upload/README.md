# H0 Open Cloud smoke test

Run `python tools/upload/smoke.py --upload-image --check-products` after filling `.env`.
Requires one asset creator ID plus a key with asset read/write and product read scopes.
It creates one small image test asset, polls completion and registers its returned ID.
Retries resume the saved operation. An ambiguous POST is not blindly repeated.

The developer product dry-run validates a local off-sale payload only. The official
create endpoint has no documented `dryRun` option, so this script never sends a product
POST. An authenticated list request checks read access, not product-write permission.
No production pass/product IDs are fabricated. Results distinguish blocked, untested,
pending, failed and successful cases. Nothing is presumed supported for this key.

If an upload type returns an authorization/unsupported error, post it to Human for
Creator Hub handling. Missing credentials are not evidence of an unsupported type.
Audio, animation, video, pass and thumbnail uploads remain untested at this kickoff.

Sources checked 2026-10-12:
- https://create.roblox.com/docs/cloud/guides/usage-assets
- https://create.roblox.com/docs/cloud/reference/features/developer-products

Do not store credentials anywhere except `.env`. Never print HTTP headers, exception
details containing requests, or raw response bodies. Do not use Roblox account cookies.
