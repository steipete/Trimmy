#!/usr/bin/env python3
"""Resolve packaged resources from Contents/Resources; SwiftPM only searches the app root."""

import subprocess
import sys
from pathlib import Path

utilities = Path(sys.argv[1])
source = subprocess.run(
    ["git", "-C", str(utilities.parents[2]), "show", "HEAD:Sources/KeyboardShortcuts/Utilities.swift"],
    check=True,
    capture_output=True,
    text=True,
).stdout
original = 'NSLocalizedString(self, bundle: .module, comment: self)'
patched = 'NSLocalizedString(self, bundle: .trimmyKeyboardShortcuts, comment: self)'

if source.count(original) != 1:
    raise SystemExit("KeyboardShortcuts resource lookup changed; review the packaging patch.")
source = source.replace(original, patched)
source += '''
private extension Bundle {
    static let trimmyKeyboardShortcuts: Bundle = Bundle.main
        .url(forResource: "KeyboardShortcuts_KeyboardShortcuts", withExtension: "bundle")
        .flatMap(Bundle.init(url:)) ?? .module
}
'''
if utilities.read_text() != source:
    utilities.chmod(utilities.stat().st_mode | 0o200)
    utilities.write_text(source)
