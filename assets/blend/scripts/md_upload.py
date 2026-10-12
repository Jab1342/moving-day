"""Claude B model upload: Blender Python -> Open Cloud Assets API (SPEC section 7 fallback path).

Run inside Blender:
    ns = {"__file__": r"<repo>/assets/blend/scripts/md_upload.py"}
    exec(open(ns["__file__"]).read(), ns)
    ns["upload_model"]("REF_Cube", "assets/export/REF_Cube.fbx")

Never logs keys, headers or response bodies. One journal entry per asset name in
assets/export/upload-journal.json, so a retry resumes the saved operation instead of
posting a duplicate. Names already in assets/registry.json are refused (a fix is a new
version of the same asset, not a second upload).
"""

import json
import re
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
UNIVERSE = "10770594715"
PLACE = "130590584225382"
BASE = "https://apis.roblox.com"
REGISTRY = ROOT / "assets" / "registry.json"
JOURNAL = ROOT / "assets" / "export" / "upload-journal.json"


def _read_env():
    # A worktree has no .env of its own; fall back to the shared checkout's ignored copy.
    path = next((p for p in (ROOT / ".env", ROOT.parent / "Moving Day" / ".env") if p.is_file()), None)
    if path is None:
        return {}
    values = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        values[name.strip()] = value.strip().strip("\"'")
    return values


def _read_json(path, default):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def _write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)


def _request(path, key, data=None, content_type=None):
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    headers = {"x-api-key": key}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(BASE + path, data=data, headers=headers)
    try:
        with urllib.request.build_opener(NoRedirect()).open(req, timeout=60) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, {}
    except (urllib.error.URLError, TimeoutError, ValueError):
        return 0, {}


def _multipart(payload, file_path):
    boundary = "MovingDay" + uuid.uuid4().hex
    head = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n{json.dumps(payload)}\r\n'
        f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{file_path.name}"\r\n'
        "Content-Type: model/fbx\r\n\r\n"
    ).encode()
    return head + file_path.read_bytes() + f"\r\n--{boundary}--\r\n".encode(), "multipart/form-data; boundary=" + boundary


def upload_model(name, rel_file, description="Moving Day model", polls=30):
    """Upload one FBX as a Model, register it, and return a status dict (never secrets)."""
    env = _read_env()
    for var, expected in (("ROBLOX_UNIVERSE_ID", UNIVERSE), ("ROBLOX_PLACE_ID", PLACE)):
        if env.get(var, expected) != expected:
            return {"name": name, "status": "WRONG_TARGET_IN_ENV"}
    key = env.get("ROBLOX_OPEN_CLOUD_API_KEY")
    user, group = env.get("ROBLOX_CREATOR_USER_ID"), env.get("ROBLOX_CREATOR_GROUP_ID")
    if not key:
        return {"name": name, "status": "BLOCKED_MISSING_ENV_KEY"}
    if bool(user) == bool(group) or not (user or group).isdigit():
        return {"name": name, "status": "BLOCKED_SET_ONE_NUMERIC_CREATOR_ID"}

    registry = _read_json(REGISTRY, [])
    existing = next((a for a in registry if a["name"] == name), None)
    if existing:
        return {"name": name, "status": "ALREADY_REGISTERED", "assetId": existing["assetId"]}

    file_path = ROOT / rel_file
    journal = _read_json(JOURNAL, {})
    entry = journal.get(name, {})
    operation = entry.get("operation")
    if entry and not operation:
        return {"name": name, "status": "UNKNOWN_PRIOR_OUTCOME_RECONCILE_BEFORE_RETRY"}
    if not operation:
        creator = {"userId": user} if user else {"groupId": group}
        payload = {
            "assetType": "Model",
            "displayName": name,
            "description": description,
            "creationContext": {"creator": creator},
        }
        data, kind = _multipart(payload, file_path)
        journal[name] = {"status": "SUBMITTING", "file": rel_file}
        _write_json(JOURNAL, journal)
        status, result = _request("/assets/v1/assets", key, data, kind)
        operation = result.get("path")
        journal[name] = {"status": status, "operation": operation, "file": rel_file}
        _write_json(JOURNAL, journal)
        if not operation:
            return {"name": name, "status": f"HTTP_{status}"}
    if not re.fullmatch(r"operations/[A-Za-z0-9_-]+", operation):
        return {"name": name, "status": "BAD_OPERATION_PATH"}
    for _ in range(polls):
        status, result = _request("/assets/v1/" + operation, key)
        if status != 200:
            return {"name": name, "status": f"POLL_HTTP_{status}"}
        if result.get("done"):
            asset_id = str(result.get("response", {}).get("assetId", ""))
            if not (asset_id.isdigit() and int(asset_id) > 0):
                return {"name": name, "status": "OPERATION_FAILED"}
            registry = _read_json(REGISTRY, [])  # re-read: Codex may have appended meanwhile
            registry.append({"name": name, "type": "Model", "assetId": asset_id, "uploadedBy": "ClaudeB", "file": rel_file})
            _write_json(REGISTRY, registry)
            journal = _read_json(JOURNAL, {})
            journal[name] = {"status": "REGISTERED", "operation": operation, "assetId": asset_id, "file": rel_file}
            _write_json(JOURNAL, journal)
            return {"name": name, "status": "UPLOAD_PASS", "assetId": asset_id}
        time.sleep(2)
    return {"name": name, "status": "PENDING_RETRY_LATER"}
