import json
import subprocess
import sys

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
version = subprocess.run([binary, '--version'], text=True, capture_output=True, check=True)
print(version.stdout.strip())
