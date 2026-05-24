# TechDocs-Mini — Update Workflow

The Update workflow is **change-driven**: it starts from the git delta, maps changes to
affected modules and design topics, and incrementally updates only impacted sections —
extending scope only when analysis reveals cascading impact.

Load `references/workflow-guide.md` for full procedural detail.

1. Parse `docs/tech-docs/index.md` → `last-scan`, `last-commit-hash`.

2. Collect changes since the last scan with two targeted git queries:
   - **Code changes:** `git log {lastHash}..HEAD --name-only --format= -- ':!docs/tech-docs/'`
     (excludes all skill-generated output under `docs/tech-docs/`)
   - **Curated changes:** `git log {lastHash}..HEAD --name-only --format= -- 'docs/tech-docs/curated/'`
     (curated files live inside `docs/tech-docs/` so the first query excludes them; this one captures them explicitly)

3. If both lists are empty: update `last-scan` and `last-commit-hash` only and report
   "No changes detected."

4. Read any curated files that appear in the curated-changes list. Map all changed files
   (code + curated) to affected modules and design topics using `references/module-heuristics.md`.
   A curated change marks its associated module(s) as affected. If `--all` is passed,
   treat all modules as affected and skip mapping. Build the affected set.
5. **Per affected module — incremental update:**
   a. Read the existing module page; note current sections, citations, cited source
      locations, and known gaps.
   b. Identify which page sections are impacted by the changed files, based on the
      evidence sources already cited in those sections and the nature of the change
      (e.g., a changed service method affects Data Flow; a new dependency affects
      Dependencies; a curated doc update affects the Curated Intent section).
   c. Re-read source files only for impacted sections — not the entire module source tree.
   d. **Scope extension (structural):** If the change is structural (new entry point,
      removed service, changed DI wiring, renamed module), extend to a full module
      re-read and rewrite the entire page.
   e. Update impacted sections in-place; preserve unchanged sections verbatim.
   f. Update page metadata (`generated-on`, `generated-from-commit`).
6. **Cross-module scope extension:** If updated analysis of a module reveals evidence
   that implies impact on another module or design topic not yet in the affected set
   (e.g., a changed shared service affects consumers in another module; a curated doc
   change shifts a cross-cutting design topic), add it to the affected set and process it.
7. Update affected design topic pages — only sections related to changed modules.
   Extend to full design-topic rewrite only if the change shifts the topic's overall
   narrative.
8. Update all report files; update `index.md` metadata
   (`last-scan` = now; `last-commit-hash` = current HEAD from `git log -1 --format=%H`).
9. Append Update entry to `docs/tech-docs/log.md`.
10. Run Verification Checklist.
11. Report: modules updated (incremental vs structural), design topics updated, scope
    extensions triggered (within-module and cross-module), curated files incorporated,
    mismatches flagged.
