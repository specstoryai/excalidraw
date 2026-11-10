# Guidelines

- For new DOM/browser API usage, use `app.ownerDocument` and `app.ownerWindow` instead of globals; without `app`, derive them from the mounted node's `ownerDocument` and its `defaultView`.
- When overriding properties of an existing type, prefer `Merge<Base, Overrides>` from `@excalidraw/common/utility-types` over `Omit<Base, keyof Overrides> & Overrides`.

## runstory

runstory checks commits in a cloud sandbox when a person asks, or after each commit when automatic checks are on. It never blocks a commit, and what it finds stays on this branch as open findings.

- Before you say a job is done, read the open findings with `runstory findings --json` or the runstory_findings tool. An empty list is a clean branch only when the answer holds no `note`.
- Fix a finding and name its id in the commit message, e.g. "Validate pasted cells (f-3500ce764be1)". The next check runs its own test, and 3 passes close it, so a fix needs no acknowledgement.
- Close a finding that no longer applies with `runstory findings acknowledge <id> --reason "what you checked"` or the runstory_acknowledge tool. A person reads the reason. A finding that also fails before your change, as `earlier_commit` shows, still applies.
- To wait for your last commit's check, run `runstory show --wait --timeout 9m --json` in a shell call of 10 minutes. Exit 8 means it still runs, so run it again. Then `result.word` is the verdict.
- You may run the command in `next`, which starts no paid check. In `runstory setup`, a failed boot may run a setup agent for 15 minutes. Tell the person about the command in `person_next`, which is theirs to run.
- `runstory run` spends money, so start a check only when the person asks. Never run a reproducer from `.runstory/repro/` on this machine.
