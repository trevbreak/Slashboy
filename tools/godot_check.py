#!/usr/bin/env python3
"""Check every GDScript in godot/ and auto-fix ':=' type-inference errors (untyped Variant values).
Prints any remaining errors. Usage: python3 tools/godot_check.py [--nofix]"""
import os, re, subprocess, sys
GODOT = os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot')
ROOT = os.path.join(os.path.dirname(__file__), '..', 'godot')
INFER = ('Cannot infer the type of', 'inferred from a Variant value')


def check(path):
    out = subprocess.run([GODOT, '--headless', '--path', ROOT, '--check-only', '--script', 'res://' + path],
                         capture_output=True, text=True, timeout=120); out = out.stdout + out.stderr
    errs = []
    lines = out.splitlines()
    for i, l in enumerate(lines):
        if 'SCRIPT ERROR' in l and 'depended' not in l and 'Identifier not found: G' not in l:
            loc = lines[i + 1] if i + 1 < len(lines) else ''
            m = re.search(r'\((res://.+?):(\d+)\)', loc)
            errs.append((l.split('Error: ', 1)[-1], m.group(1)[6:] if m else path, int(m.group(2)) if m else 0))
    return errs


def main():
    fix = '--nofix' not in sys.argv
    files = []
    for d in ['scripts', 'scripts/enemies', 'scripts/sectors']:
        for f in sorted(os.listdir(os.path.join(ROOT, d))):
            if f.endswith('.gd'):
                files.append(f'{d}/{f}')
    for _ in range(6):
        changed = False
        remaining = {}
        for f in files:
            for msg, fpath, line in check(f):
                remaining[(fpath, line, msg)] = True
        for (fpath, line, msg) in list(remaining):
            if fix and any(k in msg for k in INFER) and line > 0:
                p = os.path.join(ROOT, fpath)
                L = open(p).read().split('\n')
                new = re.sub(r'\bvar (\w+) :=', r'var \1 =', L[line - 1], count=1)
                if new != L[line - 1]:
                    L[line - 1] = new
                    open(p, 'w').write('\n'.join(L))
                    changed = True
                    del remaining[(fpath, line, msg)]
        if not changed:
            break
    for (fpath, line, msg) in sorted(remaining):
        print(f'{fpath}:{line}: {msg}')
    print('remaining errors:', len(remaining))


main()
