"""Append-only repo fallback and export of Studio read.luau JSON."""
import argparse
import json
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BOARD = ROOT / 'devboard'

def render(messages):
    lines = []
    for m in sorted(messages, key=lambda m: m['name']):
        a = m.get('attributes', m)
        lines.append(f"{m['name']} | {a.get('From')} -> {a.get('To')} | {a.get('Type')} | {a.get('Status')} | {m['Value']}")
    return '\n'.join(lines) + '\n'

def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest='command', required=True)
    post = commands.add_parser('post')
    post.add_argument('text')
    post.add_argument('--to', choices=['All', 'Codex', 'ClaudeA', 'ClaudeB', 'Human'], default='All')
    post.add_argument('--type', choices=['Info', 'Request', 'Blocker', 'Done', 'Contract'], default='Info')
    post.add_argument('--ref', default='')
    post.add_argument('--reply-to', default='')
    export = commands.add_parser('export')
    export.add_argument('json_file', type=Path)
    commands.add_parser('read')
    args = parser.parse_args()
    BOARD.mkdir(exist_ok=True)
    if args.command == 'export':
        messages = json.loads(args.json_file.read_text(encoding='utf-8'))
        (BOARD / 'BOARD_LOG.md').write_text('# Studio DevBoard export\n\n```text\n' + render(messages) + '```\n', encoding='utf-8')
        print('Exported Studio board; no messages modified.')
        return
    path = BOARD / 'board.jsonl'
    messages = [json.loads(s) for s in path.read_text(encoding='utf-8').splitlines() if s.strip()] if path.exists() else []
    if args.command == 'post':
        if len(args.text) >= 500:
            parser.error('Message must be under 500 characters')
        stamp = int(time.time())
        names = {m['name'] for m in messages}
        while f'{stamp}_Codex' in names:
            stamp += 1
        m = dict(name=f'{stamp}_Codex', From='Codex', To=args.to, Type=args.type, Status='Open', Ref=args.ref, ReplyTo=args.reply_to, Value=args.text)
        with path.open('a', encoding='utf-8') as stream:
            stream.write(json.dumps(m) + '\n')
        messages.append(m)
        (BOARD / 'board.txt').write_text(render(messages), encoding='utf-8')
    print(render(messages))

if __name__ == '__main__':
    main()
