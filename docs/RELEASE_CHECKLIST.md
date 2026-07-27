# HarkinianPad release checklist

This is the final gate for a public source snapshot or downloadable IPA.

## Every public source update

- [ ] `scripts/check-repo-safety.sh` passes.
- [ ] The pinned source revisions replay without manual edits.
- [ ] `scripts/build-ios.sh --device` produces the unsigned arm64 app.
- [ ] `scripts/package-ios.sh` accepts that app and
      `REQUIRE_SIGNED=1 scripts/package-ios.sh` rejects it.
- [ ] README setup steps and screenshots match the current interface.
- [ ] No ROM, `oot*.o2r`, `.otr`, extracted game asset, signing material,
      signed app, or IPA appears in the current tree or Git history.
- [ ] Remaining physical-device limitations are stated plainly.

## Before publishing a downloadable IPA

- [ ] The owner has selected and documented licensing terms for
      HarkinianPad-owned work and confirmed the Shipwright distribution
      boundary.
- [ ] Build from a clean checkout at a tagged commit.
- [ ] Use a deliberate distribution bundle identifier and fresh signing
      identity/profile.
- [ ] `REQUIRE_SIGNED=1 scripts/package-ios.sh` passes on the exact app being
      distributed.
- [ ] Record the tag, commit, Xcode version, SDK, bundle version, signing type,
      IPA SHA-256, and supported device/OS range in the release notes.
- [ ] Install the packaged IPA on clean physical hardware and complete Files
      import, extraction, save/load, touch, background/foreground, termination,
      relaunch, speaker audio, and controller checks.
- [ ] Confirm the IPA contains only the ROM-free `soh.o2r`; it must never
      contain the user's ROM or generated `oot.o2r`.
- [ ] Publish known limitations, installation/signing requirements, and a
      rollback path.

## Current blockers

- Audible physical-device audio is still under investigation.
- Physical controller, reconnect, rumble, and motion testing is incomplete.
- The complete lifecycle/interruption matrix remains open.
- No top-level HarkinianPad license has been selected.

Until those gates are resolved, describe this repository as a public source
preview with local Xcode installation—not a finished binary distribution.
