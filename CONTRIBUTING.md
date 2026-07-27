# Contributing to HarkinianPad

Thanks for helping make the iPhone and iPad port better.

## Before opening an issue

- Search existing issues first.
- Reproduce the problem on the latest `main` build when practical.
- Include the HarkinianPad commit, Apple device model, OS version, install
  method, input method, and exact reproduction steps.
- Attach logs or screenshots only after checking that they contain no personal
  paths, signing information, ROM data, or generated game archives.
- Never request, attach, or link to copyrighted game data.

The structured bug-report template collects the details needed to distinguish
Simulator, physical-device, audio, controller, lifecycle, and signing issues.

## Making a change

1. Run `scripts/check-repo-safety.sh`.
2. Keep the change in this repository. `sources/` contains disposable,
   fetch-only upstream inputs.
3. Edit the maintained patches or HarkinianPad assets/scripts rather than
   committing generated upstream trees.
4. Build the relevant target:

   ```sh
   scripts/build-ios.sh --simulator
   # or
   scripts/build-ios.sh --device
   ```

5. Re-run `scripts/check-repo-safety.sh` and update documentation when observed
   behavior or a release gate changes.

Pull requests should stay focused and explain the user-visible impact,
validation performed, and any physical-device checks that remain open.

## Game-data boundary

ROMs, `oot*.o2r`, `.otr`, extracted Nintendo assets, signed applications,
provisioning profiles, and IPAs must never enter Git history. Keep legal local
game data under ignored `ref/` or in the installed app's Documents container.

## Licensing

Each upstream component retains its own license and copyright. HarkinianPad
currently has no top-level license grant; contributing does not change that
status. See [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) before
proposing binary distribution.
