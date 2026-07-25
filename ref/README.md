# ref/ — local reference dump (not tracked by git)

Drop original Ocarina of Time material here for local work: your legally
acquired ROM dump (`.z64` / `.n64` / `.v64`), generated archives
(`oot.o2r`, `oot-mq.o2r`, `.otr`), extracted assets, notes, captures —
anything you need at hand while working on the port.

**Nothing in this directory is ever committed, merged, or maintained on
git.** The repository `.gitignore` excludes all of `ref/` except this
README, and additionally blocks ROM/archive file types repo-wide as a
second layer of protection. This enforces the project's asset posture
(see `docs/ios-feasibility-and-implementation-plan.md`, risk L2, and
`docs/findings/05-priorart-licensing.md` §B3): no copyrighted Nintendo
material may ever enter version control, CI artifacts, or any
distributed build. You supply your own ROM; the app converts it locally.

If `git status` ever shows a file from this directory as stageable,
treat that as a bug in `.gitignore` and fix it before committing
anything.
