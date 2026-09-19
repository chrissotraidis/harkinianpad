#!/usr/bin/env python3
import contextlib
import importlib.util
import io
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('provenance', Path(__file__).resolve().parents[1] / 'scripts/write-build-provenance.py')
provenance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provenance)


class BuildProvenanceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.app = Path(self.tmp.name) / 'HarkinianPad.app'
        self.app.mkdir()
        (self.app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'HarkinianPad', 'CFBundleIdentifier': 'test.invalid', 'DTPlatformName': 'iphoneos'}))
        (self.app / 'HarkinianPad').write_bytes(b'fixture executable')
        (self.app / 'soh.o2r').write_bytes(b'fixture port archive')

    def run_report(self, check=False):
        def command(*args):
            if args[:2] == ('git', 'status'):
                return ''
            return 'fixture-tool-or-revision'
        with patch.object(sys, 'argv', ['provenance', str(self.app)] + (['--check'] if check else [])), \
             patch.object(provenance, 'command', side_effect=command), \
             patch.object(provenance.verifier, 'verify', return_value={'schema': 1}), \
             contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            provenance.main()

    def test_report_does_not_modify_app(self):
        before = {p.name: p.read_bytes() for p in self.app.iterdir()}
        self.run_report()
        self.run_report(check=True)
        self.assertTrue(self.app.with_suffix('.build.json').is_file())
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.app.iterdir()})

    def test_changed_executable_rejected(self):
        self.run_report()
        (self.app / 'HarkinianPad').write_bytes(b'different executable')
        with self.assertRaises(SystemExit) as error:
            self.run_report(check=True)
        self.assertEqual(error.exception.code, 1)

    def test_missing_report_rejected(self):
        with self.assertRaises(SystemExit) as error:
            self.run_report(check=True)
        self.assertEqual(error.exception.code, 1)


if __name__ == '__main__':
    unittest.main()
