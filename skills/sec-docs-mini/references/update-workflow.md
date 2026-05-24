# SecDocs-Mini — Incremental (Update) Workflow

The Incremental workflow is **change-driven**: it starts from the git delta,
maps changes to affected ASVS categories, and re-assesses only impacted
requirements — extending scope only when evidence cascades.

Load `references/workflow-guide.md` for full procedural detail.

1. Parse `docs/sec-docs/index.md` YAML frontmatter → `last-scan`, `last-commit-hash`.

2. Collect changes since the last scan with two targeted git queries:
   - **Code changes:** `git log {lastHash}..HEAD --name-only --format= -- ':!docs/sec-docs/'`
     (excludes all skill-generated output under `docs/sec-docs/`)
   - **Curated changes:** `git log {lastHash}..HEAD --name-only --format= -- 'docs/sec-docs/curated/'`
     (curated files live inside `docs/sec-docs/` so the first query excludes them; this one captures them explicitly)

3. Check if `docs/sec-docs/reports/entraid/entraid-audit-latest.json` is newer than
   `last-scan`.

4. If both git lists are empty **and** no new Entra ID audit: update `last-scan` and
   `last-commit-hash` only and report "No changes detected."

5. **Map changes to categories:** Read any curated files from the curated-changes list.
   Using the Category Relevance Heuristics (see `references/workflow-guide.md`), map all
   changed files (code + curated) to the ASVS categories they may affect. Build the
   affected set. If `--category` is passed, intersect with the user-specified set.
6. **Per affected category — incremental re-assessment:**
   a. Read the existing category page from `docs/sec-docs/pages/`.
   b. Identify which requirements within the category are impacted by the changed files
      (based on the evidence sources cited and the nature of changes).
   c. Re-assess only impacted requirements (follow step 7 in
      `references/init-workflow.md` for those requirements).
   d. **Scope extension:** If re-assessment reveals that a change affects additional
      requirements in the same category (e.g., a middleware change affects all
      endpoints), extend to those requirements.
   e. Update the category page in-place: rewrite only the changed requirement sections;
      preserve unchanged sections verbatim.
   f. Update `last-updated` and `status-summary` in the page frontmatter.
7. **Cross-category extension:** If a re-assessed requirement's new evidence implies
   impact on a requirement in another category not yet in scope (e.g., a crypto change
   affects both V11 and V12), add that category to the affected set and process it.
8. Regenerate `docs/sec-docs/pages/asvs_top10_owasp.md` if any category file was updated.
9. Update `docs/sec-docs/index.md` frontmatter: `last-scan` = now (UTC ISO-8601);
   `last-commit-hash` = current HEAD from `git log -1 --format=%H`.
10. Append Incremental entry to `docs/sec-docs/log.md`.
11. Run Verification Checklist.
12. Report: categories updated (with reason), requirements re-assessed, scope extensions
    triggered, FAIL/PARTIAL counts.
