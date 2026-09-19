"""Exercise the actual maintained CMake package-patch helper without network."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'sources/Shipwright/libultraship/cmake/dependencies/git-patch.cmake'


@unittest.skipUnless(HELPER.exists(), 'Run after source bootstrap (also exercised by full-app CI)')
class DependencyPatchTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.tree = Path(self.tmp.name)
        self.run_git('init', '-q')
        self.run_git('config', 'user.name', 'Fixture')
        self.run_git('config', 'user.email', 'fixture@example.invalid')
        self.source = self.tree / 'source.txt'
        self.source.write_text('original\n')
        self.run_git('add', 'source.txt')
        self.run_git('commit', '-qm', 'base')
        self.source.write_text('patched\n')
        self.patch = self.tree / 'change.patch'
        self.patch.write_bytes(self.run_git('diff'))
        self.run_git('checkout', '--', 'source.txt')

    def run_git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.tree), *args])

    def apply(self):
        return subprocess.run(['cmake', f'-Dpatch_file={self.patch}', '-Dwith_reset=TRUE',
                               '-P', str(HELPER)], cwd=self.tree, capture_output=True)

    def test_pristine_and_already_applied(self):
        self.assertEqual(self.apply().returncode, 0)
        self.assertEqual(self.source.read_text(), 'patched\n')
        self.assertEqual(self.apply().returncode, 0)
        self.assertEqual(self.source.read_text(), 'patched\n')

    def test_failed_patch_preserves_tracked_and_untracked_edits(self):
        self.source.write_text('private changes\n')
        extra = self.tree / 'untracked.txt'
        extra.write_text('keep me\n')
        result = self.apply()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'dependency files were preserved', result.stderr)
        self.assertEqual(self.source.read_text(), 'private changes\n')
        self.assertEqual(extra.read_text(), 'keep me\n')
