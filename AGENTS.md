# Agent instructions

## Recipe-only releases

The maintainer approved recipe-only PadMint releases on 27 October 2026.
Public release assets may contain only the versioned `padmint.json` recipe and
its `SHA256SUMS`. PadMint builds the app privately for each player.

Do not publish, re-publish, or restore any IPA, APK, macOS app, or other
prebuilt game binary, or add download links to those artifacts. Binary
publication remains paused pending separate clearance in the private audit.

Before any public release, every asset must pass
`python3 ~/.codex/release-gate/release_gate.py <artifact>` and PadMint's audit
on the maintainer's machine. A failure is a stop, not a note.
Run `scripts/player-check.sh` from PadMint's current main with this game's
clean checkout before tagging, and without a checkout after publishing.
