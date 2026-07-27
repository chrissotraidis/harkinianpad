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

## Before publishing an unsigned developer-preview IPA

- [ ] The owner has selected and documented licensing terms for
      HarkinianPad-owned work and confirmed the Shipwright distribution
      boundary.
- [ ] Build from a clean checkout at a tagged commit.
- [ ] Use the stable bundle identifier
      `com.chrissotraidis.harkinianpad`.
- [ ] Set a deliberate app version and monotonically increasing build number.
- [ ] Build without `DEVELOPMENT_TEAM`, then run `scripts/package-ios.sh`.
- [ ] Confirm `REQUIRE_SIGNED=1 scripts/package-ios.sh` rejects that unsigned
      app and that the IPA contains no `_CodeSignature` or
      `embedded.mobileprovision`.
- [ ] Confirm the IPA contains only the ROM-free `soh.o2r`; it must never
      contain the user's ROM or generated `oot.o2r`.
- [ ] Re-sign and install the exact IPA with AltStore Classic on a physical
      iPad, then replay launch, audio, touch, Files import, extraction, and
      save/load without deleting the previous installation.
- [ ] Record the tag, commit, Xcode version, SDK, app version, build number,
      unsigned IPA SHA-256, and supported device/OS range in release notes.
- [ ] Publish the IPA as a GitHub prerelease with
      [`INSTALL_IPA.md`](INSTALL_IPA.md), known limitations, and an explicit
      statement that no ROM or game data is included.

## Before publishing a maintainer-signed build

- [ ] Use a deliberate distribution identity and fresh provisioning profile.
- [ ] `REQUIRE_SIGNED=1 scripts/package-ios.sh` passes on the exact app.
- [ ] Install the packaged IPA on clean physical hardware and complete the
      full lifecycle, route/interruption, and controller matrix.
- [ ] Record the signing type without publishing certificates, profiles, or
      other signing material.

## Current blockers

- The exact unsigned preview IPA has not yet completed an AltStore Classic
  re-sign/install/update replay.
- Physical controller, reconnect, rumble, and motion testing is incomplete.
- The complete lifecycle/interruption matrix remains open.
- No top-level HarkinianPad license has been selected.

Controller and lifecycle gaps may be published as explicit developer-preview
limitations. Licensing and the exact-package AltStore replay must be resolved
before attaching a public IPA. Until then, describe this repository as a
public source preview with local Xcode installation.
