# Authored audio upload

Claude A supplies final mono/stereo PCM WAV files under `assets/audio`, with an `SFX_` registry name and its intended playback use. Only authorized original/licensed recordings should be handed off. This tooling PR contains no production audio and makes no network requests during tests.

Local preflight:

```powershell
python tools/upload/audio.py SFX_Shatter assets/audio/shatter.wav
```

Actual upload, after a real source file is ready:

```powershell
python tools/upload/audio.py SFX_Shatter assets/audio/shatter.wav --upload --env-file '<primary-workspace>/.env'
```

Preflight validates PCM headers, complete sample data, mono/stereo channels, the repository audio directory, at most 20 MB and at most seven minutes. The request uses the Moving Day group, validates universe/place targets and sets expectedPrice to zero. Credentials remain in `.env`; only sanitized status and asset IDs are reported.

The operation journal is written before submission. Unknown outcomes require reconciliation, never blind reupload. A changed source digest cannot resume an earlier operation. Successful uploads append to the registry immediately and regenerate AssetIds. Run one registry writer at a time. Assets may still need moderation/experience permission; Claude A must verify playback in the actual place before calling the sound ready. API refusal goes to the human per SPEC.

Offline regression command: `python tests/test_audio_upload.py`. It verifies no network during preflight, rejected paths and truncated files, zero-fee payload, one-time registration, unknown-outcome protection and resume without duplicate creation. Full Luau/build checks remain `tools/check.ps1`.

Official reference: [Assets usage and upload limits](https://create.roblox.com/docs/cloud/guides/usage-assets).
