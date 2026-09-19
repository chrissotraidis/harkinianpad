#!/usr/bin/env python3
"""Exercise source-drift rejection without network, ROMs or a full dependency checkout."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('verify', Path(__file__).resolve().parents[1] / 'scripts/verify-sources.py')
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class SourceVerificationTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.tree = self.root / 'source'
        self.tree.mkdir()
        self.git('init', '-q')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        (self.tree / 'file.cpp').write_text('before\nunchanged\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'base')
        pin = self.git('rev-parse', 'HEAD').strip()
        (self.tree / 'file.cpp').write_text('after\nunchanged\n')
        (self.root / 'change.patch').write_text(self.git('diff'))
        self.lock = {'components': [{'name': 'fixture', 'path': 'source', 'url': 'https://example.invalid/source', 'commit': pin, 'patches': [{'path': 'change.patch'}]}]}
        self.save_lock()

    def save_lock(self):
        (self.root / 'sources.lock.json').write_text(json.dumps(self.lock))

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.tree), *args], text=True)

    def maintained_fixture(self):
        self.git('add', '.')
        self.git('commit', '-qm', 'maintained source')
        pin = self.git('rev-parse', 'HEAD').strip()
        self.lock['schema'] = 2
        self.lock['components'][0].update(commit=pin, patches=[])
        (self.root / '.gitmodules').write_text('[submodule \"source\"]\n path = source\n url = https://example.invalid/source\n')
        for args in [('init', '-q'), ('config', 'user.name', 'Fixture'),
                     ('config', 'user.email', 'fixture@example.invalid'),
                     ('update-index', '--add', '--cacheinfo', '160000', pin, 'source'),
                     ('add', '.gitmodules'), ('commit', '-qm', 'pin source')]:
            subprocess.check_call(['git', '-C', str(self.root), *args])
        self.save_lock()

    def test_maintained_graph(self):
        self.maintained_fixture()
        self.assertEqual(verify.verify(self.root)['profile'], 'maintained')
        (self.tree / 'file.cpp').write_text('unreviewed change\n')
        with self.assertRaisesRegex(ValueError, 'unexpected source'):
            verify.verify(self.root)

    def test_parent_url_disagrees(self):
        self.maintained_fixture()
        self.lock['components'][0]['url'] = 'https://example.invalid/wrong'
        self.save_lock()
        with self.assertRaisesRegex(ValueError, 'submodule URL'):
            verify.verify(self.root)

    def test_parent_gitlink_disagrees(self):
        self.maintained_fixture()
        self.lock['components'][0]['commit'] = '0' * 40
        self.save_lock()
        with self.assertRaisesRegex(ValueError, 'parent gitlink'):
            verify.verify(self.root)

    def test_prepared_and_pristine(self):
        self.assertEqual(verify.verify(self.root)['components'][0]['files'], 1)
        self.git('checkout', '--', 'file.cpp')
        verify.verify(self.root, pristine=True)
        with self.assertRaises(ValueError):
            verify.verify(self.root)

    def test_extra_edit_inside_patched_file(self):
        (self.tree / 'file.cpp').write_text('after\nsecret extra edit\n')
        with self.assertRaisesRegex(ValueError, 'unexpected source'):
            verify.verify(self.root)

    def test_new_file(self):
        (self.tree / 'extra.cpp').write_text('extra')
        with self.assertRaisesRegex(ValueError, 'unexpected source files'):
            verify.verify(self.root)

    def test_mode_change(self):
        (self.tree / 'file.cpp').chmod(0o755)
        with self.assertRaisesRegex(ValueError, 'content/mode'):
            verify.verify(self.root)

    def test_revision_mismatch(self):
        self.lock['components'][0]['commit'] = '0' * 40
        self.save_lock()
        with self.assertRaisesRegex(ValueError, 'revision mismatch'):
            verify.verify(self.root)

    def test_missing_file(self):
        (self.tree / 'file.cpp').unlink()
        with self.assertRaisesRegex(ValueError, 'missing source'):
            verify.verify(self.root)


if __name__ == '__main__':
    unittest.main()
