"""Upload authored R15 sequences, journal operations, register IDs immediately.

Uses the official Assets API Animation/model-x-rbxm support:
https://create.roblox.com/docs/cloud/guides/usage-assets
Only status codes and asset/operation identifiers are persisted. Never log credentials.
"""
import argparse
import hashlib
import json
import re
import runpy
import time
import uuid
from pathlib import Path
import smoke

ROOT = Path(__file__).resolve().parents[2]
ANIMATIONS = {name: name.replace("ANIM_", "MD_") + ".rbxm" for name in
              ("ANIM_Carry", "ANIM_CarryTwo", "ANIM_Strap", "ANIM_Recover")}

def upload(name, filename, env):
    if ANIMATIONS.get(name) != filename:
        raise ValueError("Expected an authored animation name and source")
    if (env.get("ROBLOX_UNIVERSE_ID", smoke.UNIVERSE) != smoke.UNIVERSE or
            env.get("ROBLOX_PLACE_ID", smoke.PLACE) != smoke.PLACE):
        raise ValueError("Unexpected upload target")
    registry_path = ROOT / "assets/registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    existing = next((entry for entry in registry if entry["name"] == name), None)
    if existing:
        return {"name": name, "status": "ALREADY_REGISTERED", "assetId": existing["assetId"]}
    key = env.get("ROBLOX_OPEN_CLOUD_API_KEY") or env.get("ROBLOX_API_KEY") or env.get("OPEN_CLOUD_API_KEY")
    group = env.get("ROBLOX_CREATOR_GROUP_ID")
    if not key or group != "485719152":
        return {"name": name, "status": "MISSING_KEY_OR_GROUP"}
    path = ROOT / "assets/anim" / filename
    content = path.read_bytes()
    if not content.startswith(b"<roblox!"):
        raise ValueError("Expected binary Roblox model")
    digest = hashlib.sha256(content).hexdigest()
    journal_path = ROOT / "tools/upload" / (name + "-operation.json")
    journal = json.loads(journal_path.read_text()) if journal_path.exists() else {}
    if journal.get("sourceSha256") and journal["sourceSha256"] != digest:
        return {"name": name, "status": "SOURCE_CHANGED_REQUIRES_RECONCILIATION"}
    operation = journal.get("operation")
    if journal and not operation:
        return {"name": name, "status": "PRIOR_SUBMISSION_REQUIRES_RECONCILIATION", "http": journal.get("http")}
    if not operation:
        payload = dict(assetType="Animation", displayName=name,
                       description="Moving Day original R15 animation authored by ClaudeB",
                       creationContext={"creator": {"groupId": group}})
        boundary = "MovingDay" + uuid.uuid4().hex
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n'
                + json.dumps(payload)
                + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{filename}"\r\n'
                + 'Content-Type: model/x-rbxm\r\n\r\n').encode() + content + f'\r\n--{boundary}--\r\n'.encode()
        smoke.write_json(journal_path, {"status": "SUBMITTING", "sourceSha256": digest})
        status, result = smoke.request("/assets/v1/assets", key, body, "multipart/form-data; boundary=" + boundary)
        operation = result.get("path")
        if operation and not re.fullmatch(r"operations/[A-Za-z0-9_-]+", operation):
            operation = None
        journal = {"http": status, "operation": operation, "sourceSha256": digest}
        smoke.write_json(journal_path, journal)
        if not operation:
            return {"name": name, "status": f"HTTP_{status}"}
    for _ in range(15):
        status, result = smoke.request("/assets/v1/" + operation, key)
        if status != 200:
            return {"name": name, "status": f"POLL_HTTP_{status}"}
        if result.get("done"):
            asset_id = str(result.get("response", {}).get("assetId", ""))
            if not asset_id.isdigit() or int(asset_id) <= 0:
                smoke.write_json(journal_path, {**journal, "status": "OPERATION_FAILED"})
                return {"name": name, "status": "OPERATION_FAILED"}
            registry = json.loads(registry_path.read_text(encoding="utf-8"))
            if not any(entry["name"] == name for entry in registry):
                registry.append(dict(name=name, type="Animation", assetId=asset_id,
                                     uploadedBy="Codex", file=path.relative_to(ROOT).as_posix()))
                smoke.write_json(registry_path, registry)
            runpy.run_path(str(ROOT / "tools/generate_asset_ids.py"), run_name="__main__")
            smoke.write_json(journal_path, {**journal, "status": "REGISTERED", "assetId": asset_id})
            return {"name": name, "status": "UPLOAD_PASS", "assetId": asset_id}
        time.sleep(2)
    return {"name": name, "status": "PENDING"}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    parser.add_argument("--animation", action="append", choices=tuple(ANIMATIONS))
    args = parser.parse_args()
    if args.env_file.name != ".env":
        raise ValueError("Credentials must stay in .env")
    env = {}
    for line in args.env_file.read_text(encoding="utf-8-sig").splitlines():
        if not line.strip().startswith("#") and "=" in line:
            name, value = line.split("=", 1)
            env[name.strip()] = value.strip().strip("\"'")
    if env.get("ROBLOX_UNIVERSE_ID", smoke.UNIVERSE) != smoke.UNIVERSE:
        raise ValueError("Unexpected universe")
    if env.get("ROBLOX_PLACE_ID", "130590584225382") != "130590584225382":
        raise ValueError("Unexpected place")
    reports = []
    for name in dict.fromkeys(args.animation or ("ANIM_Carry", "ANIM_CarryTwo")):
        file = ANIMATIONS[name]
        report = upload(name, file, env)
        reports.append(report)
        smoke.write_json(ROOT / "tools/upload/animation-results.json", reports)
        print(json.dumps(report))
        if report["status"] not in ("UPLOAD_PASS", "ALREADY_REGISTERED"):
            break

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError):
        raise SystemExit("Animation upload stopped; local/network data error. No request details logged.") from None
