# TechDocs — Update Workflow

The Update workflow is **change-driven**: it starts from the git delta and curated doc
changes, maps changes to affected modules and design topics, and incrementally updates
only impacted sections of existing pages — extending scope only when analysis reveals
cascading impact within or across modules.

Load `references/workflow-guide.md` for full procedural detail.

1. Parse `docs/tech-docs/index.md` → `last-scan`, per-repo `last-commit-hash`. Re-read
   all `docs/tech-docs/curated/**/*.md`; note whether any curated file has changed since
   `last-scan`.
2. Per repo: run `cd {path} && git log {lastHash}..HEAD --name-only --format=` → list of
   changed files.
3. If no repo has new commits **and** no curated docs changed: update `last-scan` only
   and report "No changes detected."
4. **Map changes to modules and design topics:** Using `references/module-heuristics.md`,
   map each changed file to the modules and design topics it may affect. A curated doc
   change also marks its associated module(s) as affected. If `--all` is passed, treat
   all modules as affected and skip this mapping. Build the affected set.
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
   (`last-scan` = now; `last-commit-hash` = current HEAD for changed repos).
9. Append Update entry to `docs/tech-docs/log.md`.
10. Run Verification Checklist.
11. Report: repos checked, modules updated (incremental vs structural), design topics
    updated, scope extensions triggered (within-module and cross-module), curated files
    incorporated, mismatches flagged.
