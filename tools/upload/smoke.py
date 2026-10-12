"""H0 Open Cloud smoke test. Never logs keys, headers, or response bodies.

Default: local image/product preflight. --upload-image: one real image upload.
--check-products: authenticated read only. Product creation is intentionally absent:
the documented product endpoint has no dry-run parameter.
"""
import argparse
import json
import re
import runpy
import struct
import time
import urllib.error
import urllib.request
import uuid
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UNIVERSE = '10770594715'
PLACE = '130590584225382'
BASE = 'https://apis.roblox.com'

def read_env():
    path = ROOT / '.env'
    if not path.is_file():
        return {}
    values = {}
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        name, value = line.split('=', 1)
        values[name.strip()] = value.strip().strip('\"\'')
    return values

def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)

def make_fixture():
    # A plain color calibration PNG, not a production game image.
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)
    pixels = b''.join(b'\0' + bytes([42, 135, 190, 255]) * 16 for _ in range(16))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 16, 16, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')
    path = ROOT / 'assets/images/H0_UploadProbe.png'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)
    return path

def multipart(fields, image=None):
    boundary = 'MovingDay' + uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    if image:
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="upload.png"\r\nContent-Type: image/png\r\n\r\n'.encode() + image.read_bytes() + b'\r\n')
    parts.append(f'--{boundary}--\r\n'.encode())
    return b''.join(parts), 'multipart/form-data; boundary=' + boundary

def request(path, key, data=None, content_type=None):
    # Only verified Roblox API paths; disallow redirects to prevent credential forwarding.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    headers = {'x-api-key': key}
    if content_type:
        headers['Content-Type'] = content_type
    req = urllib.request.Request(BASE + path, data=data, headers=headers)
    try:
        with urllib.request.build_opener(NoRedirect()).open(req, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, {}  # Never print response bodies or request objects.
    except (urllib.error.URLError, TimeoutError, ValueError):
        return 0, {}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--upload-image', action='store_true')
    parser.add_argument('--check-products', action='store_true')
    parser.add_argument('--image-file', type=Path)
    parser.add_argument('--asset-name', default='H0_UploadProbe')
    parser.add_argument('--report', default='tools/upload/smoke-results.json')
    args = parser.parse_args()
    env = read_env()
    for name, expected in [('ROBLOX_UNIVERSE_ID', UNIVERSE), ('ROBLOX_PLACE_ID', PLACE)]:
        if env.get(name, expected) != expected:
            raise SystemExit('Configured target does not match Moving Day; stopped.')
    key = env.get('ROBLOX_OPEN_CLOUD_API_KEY') or env.get('ROBLOX_API_KEY') or env.get('OPEN_CLOUD_API_KEY')
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', args.asset_name):
        parser.error('Use a simple registry asset name')
    fixture = (ROOT / args.image_file).resolve() if args.image_file else make_fixture()
    if not fixture.is_relative_to(ROOT) or not fixture.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'):
        parser.error('Image must be a PNG inside this repository')
    report_path = (ROOT / args.report).resolve()
    if not report_path.is_relative_to(ROOT / 'tools/upload'):
        parser.error('Report must be inside tools/upload')
    product = dict(name='Moving Day H0 Probe', description='Local dry-run only; never submitted.', isForSale=False, price=19, isRegionalPricingEnabled=True, isManagedPricingEnabled=True)
    assert isinstance(product['name'], str) and 0 < len(product['name']) <= 50
    assert type(product['price']) is int and product['price'] > 0
    assert product['isForSale'] is False
    assert product['isRegionalPricingEnabled'] is True and product['isManagedPricingEnabled'] is True
    dry_body, dry_content_type = multipart({k: str(v).lower() if isinstance(v, bool) else str(v) for k, v in product.items()})
    assert b'name="isForSale"\r\n\r\nfalse' in dry_body and dry_content_type.startswith('multipart/form-data;')
    report = dict(image='NOT_TESTED', product='LOCAL_DRY_RUN_PASS', productCreate='NOT_TESTED_NO_DOCUMENTED_DRY_RUN', credentialsPresent=bool(key), productPayload=product)
    if args.check_products:
        if key:
            status, _ = request(f'/developer-products/v2/universes/{UNIVERSE}/developer-products/creator?pageSize=1', key)
            report['productRead'] = f'HTTP_{status}'
        else:
            report['productRead'] = 'BLOCKED_MISSING_ENV_KEY'
    if args.upload_image:
        user, group = env.get('ROBLOX_CREATOR_USER_ID'), env.get('ROBLOX_CREATOR_GROUP_ID')
        if not key:
            report['image'] = 'BLOCKED_MISSING_ENV_KEY'
        elif bool(user) == bool(group) or not (user or group).isdigit():
            report['image'] = 'BLOCKED_SET_ONE_NUMERIC_CREATOR_ID'
        else:
            registry_path = ROOT / 'assets/registry.json'
            registry = json.loads(registry_path.read_text(encoding='utf-8'))
            existing = next((a for a in registry if a['name'] == args.asset_name), None)
            journal_path = ROOT / 'tools/upload' / ('image-operation.json' if args.asset_name == 'H0_UploadProbe' else args.asset_name + '-operation.json')
            if existing:
                report['image'] = 'ALREADY_REGISTERED'
                report['assetId'] = existing['assetId']
            else:
                journal = json.loads(journal_path.read_text()) if journal_path.exists() else {}
                operation = journal.get('operation')
                if journal and not operation:
                    report['image'] = 'UNKNOWN_PRIOR_OUTCOME_RECONCILE_BEFORE_RETRY'
                else:
                    if not operation:
                        creator = {'userId': user} if user else {'groupId': group}
                        payload = dict(assetType='Image', displayName=args.asset_name, description='Moving Day shared image asset', creationContext={'creator': creator})
                        data, kind = multipart({'request': json.dumps(payload)}, fixture)
                        write_json(journal_path, {'status': 'SUBMITTING'})
                        status, result = request('/assets/v1/assets', key, data, kind)
                        operation = result.get('path')
                        write_json(journal_path, {'status': status, 'operation': operation})
                        report['image'] = f'HTTP_{status}'
                    if operation and re.fullmatch(r'operations/[A-Za-z0-9_-]+', operation):
                        report['image'] = 'PENDING'
                        for _ in range(10):
                            status, result = request('/assets/v1/' + operation, key)
                            if status != 200:
                                report['image'] = f'POLL_HTTP_{status}'
                                break
                            if result.get('done'):
                                response = result.get('response', {})
                                asset_id = str(response.get('assetId', ''))
                                if asset_id.isdigit() and int(asset_id) > 0:
                                    # Re-read to preserve assets ClaudeB registered during polling.
                                    registry = json.loads(registry_path.read_text(encoding='utf-8'))
                                    registry.append(dict(name=args.asset_name, type='Image', assetId=asset_id, uploadedBy='Codex', file=fixture.relative_to(ROOT).as_posix()))
                                    write_json(registry_path, registry)
                                    runpy.run_path(str(ROOT / 'tools/generate_asset_ids.py'), run_name='__main__')
                                    report['image'] = 'UPLOAD_PASS'
                                    report['assetId'] = asset_id
                                else:
                                    report['image'] = 'OPERATION_FAILED'
                                break
                            time.sleep(2)
    write_json(report_path, report)
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError):
        raise SystemExit('Smoke test stopped on local data/network error; no request details logged.') from None
