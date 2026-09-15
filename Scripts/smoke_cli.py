import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = sys.argv[1]
cases = [
    ('explicit stdin', 'echo hello \\\n  world', ['--trim', '-'], 'echo hello world', 0),
    ('short force option', 'echo one\necho two\necho three', ['--trim', '-f'], 'echo one echo two echo three', 0),
    ('continuation', 'echo hello \\\n  world', [], 'echo hello world', 0),
    ('plain text', 'ordinary prose stays intact', [], 'ordinary prose stays intact', 2),
    ('YAML scalar', 'script: |\n  $ echo one\n  $ echo two', [], 'script: |\n  $ echo one\n  $ echo two', 2),
    ('forced command', 'echo one\necho two\necho three', ['--force'], 'echo one echo two echo three', 0),
    ('terminal gutter', '│ echo hello \\\n│ world', [], 'echo hello world', 0),
]
for label, original, args, expected, code in cases:
    completed = subprocess.run([binary, '--json', *args], input=original, text=True, capture_output=True)
    assert completed.returncode == code, (label, completed.returncode, completed.stderr)
    result = json.loads(completed.stdout)
    assert result == {'original': original, 'trimmed': expected, 'transformed': code == 0}, (label, result)
    print(f'PASS {label}: exit {code}, {result["trimmed"]!r}')
for args in [['--unknown'], ['--aggressiveness', 'eager']]:
    completed = subprocess.run([binary, *args], input='echo hello', text=True, capture_output=True)
    assert completed.returncode == 1 and not completed.stdout and completed.stderr, (args, completed)
    print(f'PASS invalid arguments: {args!r}')
with tempfile.TemporaryDirectory() as temporary:
    directory = Path(temporary)
    invalid = directory / 'invalid-utf8.txt'
    invalid.write_bytes(b'\xff')
    for label, args, data, source in [
        ('missing file', ['--trim', str(directory / 'missing.txt')], b'', 'missing.txt'),
        ('directory input', ['--trim', str(directory)], b'', temporary),
        ('invalid UTF-8 file', ['--trim', str(invalid)], b'', 'invalid-utf8.txt'),
        ('invalid UTF-8 stdin', ['--trim', '-'], b'\xff', 'stdin'),
    ]:
        completed = subprocess.run([binary, *args], input=data, capture_output=True)
        error = completed.stderr.decode()
        assert completed.returncode == 1 and not completed.stdout, (label, completed)
        assert 'Failed to read' in error and source in error, (label, error)
        assert 'No input provided' not in error, (label, error)
        print(f'PASS {label}: exit 1, source and read error reported')
    empty = subprocess.run([binary, '--trim', '-'], input=b'', capture_output=True)
    assert empty.returncode == 1 and b'No input provided' in empty.stderr, empty
    descriptor = os.open(directory, os.O_RDONLY)
    try:
        unreadable = subprocess.run([binary, '--trim', '-'], stdin=descriptor, capture_output=True)
    finally:
        os.close(descriptor)
    assert unreadable.returncode == 1 and not unreadable.stdout, unreadable
    assert b'Failed to read stdin' in unreadable.stderr, unreadable
    print('PASS stdin read failure: exit 1, source and read error reported')
version = subprocess.run([binary, '--version'], text=True, capture_output=True, check=True)
print(version.stdout.strip())
