# CraftDocs — Update Workflow

The Update workflow is **change-driven**: it starts from the git delta and curated doc
changes, maps changes to affected modules, determines which analysis passes are
impacted, and incrementally updates only affected findings — extending scope only when
analysis reveals cascading impact within or across modules.

Load `references/workflow-guide.md` for full procedural detail.

1. Parse `docs/craft-docs/index.md` → `last-scan`, per-repo `last-commit-hash`, per-repo
   `architecture-style`. Re-read all curated docs; note whether any curated file or
   architecture-style declaration has changed since `last-scan`.
2. Per repo: run `cd {path} && git log {lastHash}..HEAD --name-only --format=` → list of
   changed files.
3. If no repo has new commits **and** no curated docs changed **and** no
   architecture-style shift detected: update `last-scan` only and report
   "No changes detected."
4. **Map changes to modules:** Using `references/module-heuristics.md`, map each changed
   file to the modules it may affect. A curated doc change or a detected style shift also
   marks its associated module(s) as affected. If `--all` is passed, treat all modules as
   affected and skip this mapping. Build the affected set.
5. Re-detect architecture style for each affected module — it may have shifted since the
   last run.
6. **Per affected module — incremental analysis:**
   a. Read the existing module page; note current findings, their `First detected` dates,
      and cited source locations.
   b. Classify the change impact: **structural** (new entry point, removed service,
      changed DI wiring, renamed module, architecture-style shift) or **incremental**
      (method-level change, new field, modified logic within existing structure). See
      `references/workflow-guide.md` Step 5 for the classification table.
   c. For **structural** changes: re-recover design and re-run all four passes in order
      — Architecture → SOLID → Clean Code → Testability (full module rewrite).
   d. For **incremental** changes: identify which of the four passes are affected by the
      change type; re-run only those passes on the changed code area; update findings
      surgically.
   e. **Within-module scope extension:** If a re-run pass produces a finding that implies
      impact on an earlier pass (e.g., a new SOLID finding reveals an Architecture
      issue), extend backward and re-run the earlier pass.
   f. Preserve `First detected` on persisting findings; mark resolved findings for removal
      from active reports.
7. **Cross-module scope extension:** If updated analysis of a module reveals evidence that
   implies impact on another module not yet in the affected set (e.g., a changed shared
   abstraction affects consumers in another module; a curated style declaration change
   shifts cross-cutting design decisions), add it to the affected set and process it.
8. Update consolidated reports: add new findings, remove resolved findings (history stays
   in log), preserve `First detected` on persisting findings.
9. Update `index.md` metadata (`last-scan`, per-repo `last-commit-hash` and
   `architecture-style`, finding counts).
10. Append Update entry to `log.md`.
11. Run Verification Checklist.
12. Report: modules updated (structural vs incremental), passes re-run, within-module and
    cross-module scope extensions triggered, new vs resolved findings, curated files
    incorporated.
