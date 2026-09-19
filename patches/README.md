# Historical Preview 5 preparation

These nine patches and the icon overlay described by `preview5-source.lock.json`
record the pre-migration effective source. They are retained for comparison and
rollback; normal bootstrap/build commands do not apply them. Make new fixes in
maintained source and update the immutable submodule pins.

The mapping to ordinary source commits and upstream bases is in
[MODERNIZATION.md](../docs/MODERNIZATION.md). libultraship's ImGui/StormLib package
patches are separate dependency exceptions; they do not carry HarkinianPad's
main runtime behavior.
