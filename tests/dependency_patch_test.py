"""Exercise the actual maintained CMake package-patch helper without network."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'sources/Shipwright/libultraship/cmake/dependencies/git-patch.cmake'
PATCHES = HELPER.parent / 'patches'
SDL_SOURCE = ROOT / 'build-ios-soh/_deps/sdl2-src'


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


@unittest.skipUnless((SDL_SOURCE / '.git').exists(), 'Run after SDL2 source population')
class SDLScenePatchTest(unittest.TestCase):
    """Use the pinned SDL preimages, never modify the real dependency cache."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.tree = Path(self.tmp.name)
        patches = [PATCHES / 'sdl2-uikit-scenes.patch', PATCHES / 'sdl2-uikit-window-ownership.patch']
        names = set()
        for patch in patches:
            for line in patch.read_text().splitlines():
                if line.startswith('--- a/'):
                    names.add(line[6:])
        for name in names:
            target = self.tree / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(subprocess.check_output(['git', '-C', str(SDL_SOURCE), 'show',
                '5d249570393f7a37e037abf22cd6012a4cc56a71:' + name]))
        subprocess.check_call(['git', 'init', '-q', str(self.tree)])

    def apply(self, name='sdl2-uikit-scenes.patch'):
        return subprocess.run(['cmake', f'-Dpatch_file={PATCHES / name}',
                              f'-Dfallback_patch_file={PATCHES / "sdl2-uikit-window-ownership.patch"}',
                              '-P', str(HELPER)],
                              cwd=self.tree, capture_output=True)

    def snapshot(self):
        return {str(p.relative_to(self.tree)): p.read_bytes() for p in self.tree.rglob('*')
                if p.is_file() and '.git' not in p.relative_to(self.tree).parts}

    def test_existing_scene_checkout_upgrades_and_reruns(self):
        self.assertEqual(self.apply().returncode, 0)
        # Remove only the follow-up from this isolated fixture to recreate a
        # cache holding the previous scene/orientation patch, without needing
        # historical commits in CI.
        subprocess.check_call(['git', 'apply', '--reverse',
            str(PATCHES / 'sdl2-uikit-window-ownership.patch')], cwd=self.tree)
        self.assertNotIn(b'UIKit_AdoptOwningScene', self.snapshot()['src/video/uikit/SDL_uikitwindow.m'])
        self.assertEqual(self.apply().returncode, 0)
        first = self.snapshot()
        self.assertEqual(self.apply().returncode, 0)
        self.assertEqual(self.snapshot(), first)
        self.assertIn(b'windowScene.effectiveGeometry.interfaceOrientation',
                      first['src/video/uikit/SDL_uikitvideo.m'])
        self.assertIn(b'void UIKit_AdoptOwningScene', first['src/video/uikit/SDL_uikitwindow.m'])

    def test_incompatible_orientation_edits_are_preserved(self):
        self.assertEqual(self.apply().returncode, 0)
        source = self.tree / 'src/video/uikit/SDL_uikitvideo.m'
        source.write_bytes(source.read_bytes().replace(b'CGRect UIKit_ComputeViewFrame',
                                                       b'CGRect PrivateComputeViewFrame'))
        extra = self.tree / 'private-note.txt'
        extra.write_text('preserve this\n')
        before = self.snapshot()
        result = self.apply()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'dependency files were preserved', result.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_pristine_checkout_and_complete_patch_rerun(self):
        self.assertEqual(self.apply().returncode, 0)
        first = self.snapshot()
        self.assertEqual(self.apply().returncode, 0)
        self.assertEqual(self.snapshot(), first)
