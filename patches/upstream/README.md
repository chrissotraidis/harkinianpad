# Patches against the original upstream projects

HarkinianPad's changes to Shipwright, libultraship and ZAPDTR, expressed as
patches against the exact upstream commits recorded in `sources.json`.
`scripts/fetch-upstream-sources.py DEST` clones the upstream projects, applies
these patches and verifies each resulting tree against its recorded ID, which
reproduces the fork commits pinned in `sources.lock.json` without fetching the
forks. The existing fork-based build is unchanged.

Some hunks change files in Shipwright's decompiled game source
(`soh/src/code/*.c`); like any unified diff, they include a few lines of the
surrounding upstream source as context. The patches contain no game assets or
ROM data and pass the maintainer's release gate.

