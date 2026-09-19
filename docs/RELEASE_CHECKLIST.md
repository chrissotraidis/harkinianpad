# HarkinianPad release checklist

This is the final gate for a public source snapshot or downloadable IPA.

## Every public source update

- [ ] `scripts/check-repo-safety.sh` passes.
- [ ] `scripts/verify-sources.py` passes on the prepared source; pins, file
      contents and modes agree with `sources.lock.json`.
- [ ] `scripts/build-ios.sh --device` produces the unsigned arm64 app.
- [ ] `scripts/package-ios.sh` accepts that app and
      `REQUIRE_SIGNED=1 scripts/package-ios.sh` rejects it.
- [ ] README setup steps and screenshots match the current interface.
- [ ] No ROM, `oot*.o2r`, `.otr`, extracted game asset, signing material,
      signed app, or IPA appears in the current tree or Git history.
- [ ] Remaining physical-device limitations are stated plainly.

## Before publishing an unsigned developer-preview IPA

- [ ] [`RIGHTS_AND_LICENSES.md`](../RIGHTS_AND_LICENSES.md) still limits the
      HarkinianPad notice to project-owned work and does not claim to
      relicense Shipwright, dependencies, Nintendo material, or game data.
- [ ] Release copy describes HarkinianPad as source-available rather than
      broadly redistributable open source.
- [ ] Distribution remains a free, unsigned, ROM-free community preview
      consistent with Shipwright's documented
      [modding and distributable-build workflow](https://github.com/HarbourMasters/Shipwright/blob/da4e6dc3321bda48a313b162261156580bc376f4/docs/MODDING.md).
- [ ] Resolve the source/history distribution and full source-delivery gates
      recorded in [modernization qualification](MODERNIZATION.md).
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
- [ ] Confirm the IPA carries `RIGHTS_AND_LICENSES.md` and the discovered
      dependency license files under `ThirdPartyLicenses/`, plus a matching
      `BUILD_PROVENANCE.json`.
- [ ] For App Store or TestFlight distribution, add and audit the required
      Apple privacy manifest. The GitHub unsigned preview does not currently
      claim official-store readiness.
- [ ] Re-sign and update-install the exact IPA on physical iPhone and iPad.
      Prefer AltStore Classic when available. Apple Development signing of the
      exact extracted payload is an accepted fallback when AltStore is not
      installed; record that limitation in the release notes.
- [ ] Replay launch, touch, Files/imported-data visibility, and save
      preservation without deleting the previous installation.
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

- Automated stale-handle, reconnect, slot, held-input release, and foreground
  coverage passes. Physical Bluetooth, wired, natural-sleep, full-mapping,
  rumble/motion, and two-controller acceptance is still incomplete.
- The complete lifecycle/interruption matrix remains open.
- Shipwright maintained-source/history redistribution and complete source
  delivery remain unqualified. The community modding guide does not settle
  every component's rights. Paid/commercial/official-store use also requires
  clarification; see [the scoped record](MODERNIZATION.md).
- Xcode 27 cannot qualify the unchanged iOS 14 deployment floor; retain a
  compatible toolchain for that release check.

Controller and lifecycle gaps may be published as explicit developer-preview
limitations. Every public IPA must carry the scoped rights notice and
third-party license files, and its exact payload must pass an in-place
physical-device update before publication.
