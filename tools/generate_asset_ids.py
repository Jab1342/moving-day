"""Generate Luau asset constants only from registered, real numeric IDs."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def generate():
    registry = json.loads((ROOT / 'assets/registry.json').read_text(encoding='utf-8'))
    seen = set()
    lines = ['--!strict', '-- Generated from assets/registry.json. Do not edit by hand.', 'return {']
    for asset in sorted(registry, key=lambda a: a['name']):
        name, asset_id = asset['name'], str(asset['assetId'])
        if name in seen or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', name):
            raise ValueError('Duplicate or invalid registry name')
        if not asset_id.isdigit() or int(asset_id) <= 0:
            raise ValueError('Registry asset ID must be positive numeric')
        seen.add(name)
        lines.append(f'\t{name} = "rbxassetid://{asset_id}",')
    lines.append('}')
    (ROOT / 'src/shared/AssetIds.luau').write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')

if __name__ == '__main__':
    generate()
