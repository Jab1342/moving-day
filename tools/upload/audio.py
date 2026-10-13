"""Upload authored PCM WAV audio with a resumable operation journal.

No network request without --upload. Credentials stay in .env and are never logged.
Official limits: https://create.roblox.com/docs/cloud/guides/usage-assets
"""
import argparse
import hashlib
import io
import json
import re
import runpy
import time
import uuid
import wave
from pathlib import Path

import smoke

ROOT = Path(__file__).resolve().parents[2]


def preflight(name, path):
    if not re.fullmatch(r"SFX_[A-Za-z0-9_]+", name):
        raise ValueError("Use an SFX_ registry name")
    path = (ROOT / path).resolve()
    if not path.is_relative_to((ROOT / "assets/audio").resolve()) or path.suffix.lower() != ".wav":
        raise ValueError("Audio must be a WAV inside assets/audio")
    if not 0 < path.stat().st_size <= 20_000_000:
        raise ValueError("Audio exceeds the 20 MB upload limit")
    content = path.read_bytes()
    with wave.open(io.BytesIO(content), "rb") as stream:
        frames, rate = stream.getnframes(), stream.getframerate()
        if stream.getcomptype() != "NONE" or stream.getnchannels() not in (1, 2):
            raise ValueError("Expected mono or stereo PCM WAV")
        if rate <= 0 or not 0 < frames / rate <= 420:
            raise ValueError("Audio must be nonempty and at most 7 minutes")
        expected = frames * stream.getnchannels() * stream.getsampwidth()
        if len(stream.readframes(frames)) != expected:
            raise ValueError("Truncated WAV data")
    return path, content, hashlib.sha256(content).hexdigest()


def upload(name, file, env, *, submit=False):
    path, content, digest = preflight(name, file)
    relative = path.relative_to(ROOT).as_posix()
    registry_path = ROOT / "assets/registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    existing = next((entry for entry in registry if entry["name"] == name), None)
    if existing:
        if existing["type"] != "Audio" or existing["file"] != relative:
            raise ValueError("Registry name belongs to another asset")
        return {"name": name, "status": "ALREADY_REGISTERED", "assetId": existing["assetId"]}
    if not submit:
        return {"name": name, "status": "LOCAL_PREFLIGHT_PASS", "sha256": digest}
    for key, target in (("ROBLOX_UNIVERSE_ID", smoke.UNIVERSE), ("ROBLOX_PLACE_ID", smoke.PLACE)):
        if env.get(key, target) != target:
            raise ValueError("Unexpected Moving Day target")
    key = env.get("ROBLOX_OPEN_CLOUD_API_KEY") or env.get("ROBLOX_API_KEY") or env.get("OPEN_CLOUD_API_KEY")
    group = env.get("ROBLOX_CREATOR_GROUP_ID")
    if not key or group != "485719152":
        return {"name": name, "status": "MISSING_KEY_OR_MOVING_DAY_GROUP"}
    journal_path = ROOT / "tools/upload" / (name + "-operation.json")
    journal = json.loads(journal_path.read_text(encoding="utf-8")) if journal_path.exists() else {}
    if journal and (journal.get("sha256") != digest or journal.get("file") != relative):
        raise ValueError("Source changed after submission; reconcile the original operation")
    operation = journal.get("operation")
    if journal and not operation:
        return {"name": name, "status": "PRIOR_SUBMISSION_REQUIRES_RECONCILIATION"}
    if operation and not re.fullmatch(r"operations/[A-Za-z0-9_-]+", operation):
        raise ValueError("Invalid operation journal")
    if not operation:
        payload = {"assetType": "Audio", "displayName": name,
                   "description": "Moving Day authored sound effect",
                   "creationContext": {"creator": {"groupId": group}, "expectedPrice": 0}}
        boundary = "MovingDay" + uuid.uuid4().hex
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n'
                + json.dumps(payload)
                + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="audio.wav"\r\n'
                + 'Content-Type: audio/wav\r\n\r\n').encode() + content + f'\r\n--{boundary}--\r\n'.encode()
        journal = {"status": "SUBMITTING", "sha256": digest, "file": relative}
        smoke.write_json(journal_path, journal)
        status, result = smoke.request("/assets/v1/assets", key, body, "multipart/form-data; boundary=" + boundary)
        operation = result.get("path")
        if not isinstance(operation, str) or not re.fullmatch(r"operations/[A-Za-z0-9_-]+", operation):
            operation = None
        journal.update(http=status, operation=operation)
        smoke.write_json(journal_path, journal)
        if not operation:
            return {"name": name, "status": f"HTTP_{status}"}
    for _ in range(10):
        status, result = smoke.request("/assets/v1/" + operation, key)
        if status != 200:
            return {"name": name, "status": f"POLL_HTTP_{status}"}
        if result.get("done"):
            asset_id = str(result.get("response", {}).get("assetId", ""))
            if not asset_id.isdigit() or int(asset_id) <= 0:
                smoke.write_json(journal_path, {**journal, "status": "OPERATION_FAILED"})
                return {"name": name, "status": "OPERATION_FAILED"}
            registry = json.loads(registry_path.read_text(encoding="utf-8"))
            if any(entry["name"] == name for entry in registry):
                raise ValueError("Concurrent registry writer; reconcile before continuing")
            registry.append({"name": name, "type": "Audio", "assetId": asset_id,
                             "uploadedBy": "Codex", "file": relative})
            smoke.write_json(registry_path, registry)
            runpy.run_path(str(ROOT / "tools/generate_asset_ids.py"), run_name="__main__")
            smoke.write_json(journal_path, {**journal, "status": "REGISTERED", "assetId": asset_id})
            return {"name": name, "status": "UPLOAD_PASS", "assetId": asset_id}
        time.sleep(2)
    return {"name": name, "status": "PENDING"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("file", type=Path)
    parser.add_argument("--upload", action="store_true")
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    args = parser.parse_args()
    env = smoke.read_env(args.env_file) if args.upload else {}
    report = upload(args.name, args.file, env, submit=args.upload)
    smoke.write_json(ROOT / "tools/upload" / (args.name + "-results.json"), report)
    print(json.dumps(report))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, EOFError, wave.Error):
        raise SystemExit("Audio upload stopped: invalid local data or network result. No credentials logged.") from None
