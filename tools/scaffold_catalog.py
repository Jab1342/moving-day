"""Reproduce the spec's catalogue without Roblox dependencies."""
from pathlib import Path

ITEMS = [
    ("CardboardBox", "Cardboard box", "One", 20, 0.5),
    ("Chair", "Chair", "One", 30, 0.6),
    ("PottedPlant", "Potted plant", "One", 25, 0.8),
    ("Lamp", "Lamp", "One", 40, 1.5),
    ("Microwave", "Microwave", "One", 60, 1.0),
    ("Vase", "Vase", "One", 80, 2.5),
    ("Mirror", "Mirror", "One", 120, 3.0),
    ("TV", "TV", "One", 150, 2.0),
    ("Mattress", "Mattress", "Two", 90, 0.2),
    ("Bookshelf", "Bookshelf", "Two", 110, 0.7),
    ("Couch", "Couch", "Two", 200, 0.4),
    ("Fridge", "Fridge", "Two", 250, 0.8),
    ("GrandfatherClock", "Grandfather clock", "Two", 350, 1.8),
    ("Aquarium", "Aquarium", "Two", 400, 2.5),
    ("Piano", "Piano", "Two", 600, 1.2),
]

if __name__ == "__main__":
    lines = ['--!strict', '-- STUB(Codex): massScale = 1 pending ClaudeA feel tuning; optional sounds unset.', '-- IDs and model names confirmed by ClaudeA on DevBoard 1791846961_ClaudeA.', 'return {']
    for model_id, name, carry, value, fragility in ITEMS:
        item_id = {'CardboardBox': 'box', 'PottedPlant': 'plant', 'GrandfatherClock': 'clock'}.get(model_id, model_id.lower())
        lines.extend([
            f'\t{item_id} = {{',
            f'\t\tid = "{item_id}", displayName = "{name}", carry = "{carry}",',
            f'\t\tvalue = {value}, fragility = {fragility}, massScale = 1,',
            f'\t\tmodel = "FUR_{model_id}", fractured = "FUR_{model_id}_Frac",',
            '\t},',
        ])
    lines.append('}')
    (Path(__file__).resolve().parents[1] / 'src/shared/ItemDefs.luau').write_text('\n'.join(lines)+'\n', encoding='utf-8', newline='\n')
