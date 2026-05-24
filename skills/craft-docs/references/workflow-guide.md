# Craft Workflow Guide

Full procedural workflow for the hybrid craft documentation strategy.

**RULE:** Curated docs declare intent. Generated docs recover observed design and grade craft alignment in fixed order: Architecture → SOLID → Clean Code → Testability. Source code is the only proof.

**CONSTRAINT [HARD]:** Analysis order is fixed. A finding produced by an earlier pass shadows any candidate finding for the same code location in a later pass — do not double-file. Each aspect file cross-references the others to enforce this.

**CONSTRAINT [HARD]:** All findings use the **Critical / Major / Minor** layout defined in `references/output-format.md`. No other priority scheme.

---

## Part A — Init Mode

**Trigger:** `--init` flag passed, OR `docs/craft-docs/index.md` does not exist.

### Step 1 — Create directory structure

Create these directories if absent:

```text
docs/craft-docs/
docs/craft-docs/curated/
docs/craft-docs/curated/adrs/
docs/craft-docs/curated/design-notes/
docs/craft-docs/pages/
docs/craft-docs/pages/modules/
docs/craft-docs/pages/design/
docs/craft-docs/reports/
```

`docs/craft-docs/curated/` and its subdirectories are read-only for the agent.
Create only the empty shell so the user can start filling it.

### Step 2 — Discover repositories

Scan workspace root for directories containing `.git/`.

```bash
# PowerShell
Get-ChildItem -Path . -Directory | Where-Object { Test-Path (Join-Path $_.FullName ".git") }

# bash
find . -maxdepth 2 -name ".git" -type d | sed 's|/.git||' | sort
```

Record per repo:

- `Name`
- `Path` (workspace-relative)
- `last-commit-hash` (`cd {repo-path} && git log -1 --format=%H`)

### Step 3 — Read curated docs and ADRs

Read all `docs/craft-docs/curated/**/*.md`.

For each file:

1. Parse YAML frontmatter where present (`module:`, `topic:`, `adr:`,
   `decision:`, `status:`, `architecture-style:`).
2. Classify as one of:
   - **Design note** — intended design for a module/component.
   - **ADR** — Architecture Decision Record with status (Proposed/Accepted/
     Superseded/Deprecated).
   - **Style declaration** — explicit architectural style for a repo/module.
   - **Refactoring constraint** — do-not-touch notes, accepted trade-offs,
     known debt with owner.
   - **Project glossary** — terms and vocabulary used in the codebase.
3. Index by module/topic/repo so generated pages cite the right curated
   source.
4. Record ADR status. Only `Accepted` or `Active` ADRs count as authoritative
   trade-off acceptance.

### Step 4 — Detect architecture style per repo or module

Apply `references/aspects/architecture.md`'s style-detection table:

- If a curated style declaration exists for the repo, use it (cite the
  curated file).
- Otherwise pick the style with the strongest signal: Layered, Hexagonal,
  Clean Architecture, Vertical Slice, Event-Driven, or `Unclear`.
- If two styles signal equally, pick the inner one and note the outer in
  Design (Recovered).
- If style is `Unclear`, file a Major architecture finding per
  `aspects/architecture.md` and skip style-specific rules for that scope.

**Load only the matching `architectures/{style}.md` file.** Do not mix
rules from multiple style files.

### Step 5 — Detect technology stack and modules

Use `references/module-heuristics.md`:

1. Step 0 for hypotheses and craft risk framing.
2. Step 1 for stack detection.
3. Step 2 for module boundary derivation.

Store module records:

- module name and slug
- source repo
- module root path
- detected architecture style (inherited from repo unless module differs)
- likely related curated docs and ADRs

Required slug format for module pages:

- `{repo-name}-{module-name}` in lowercase kebab-case
- if repo last token equals module first token, remove the repeated module
  token
- example: `cold-wave-api` + `api-host` => `cold-wave-api-host`

### Step 6 — Recover design per module

For each module:

1. Read key source files indicated by stack heuristics.
2. Recover observed design (not assumed):
   - Key abstractions (types, interfaces, role).
   - Layering and dependency direction.
   - Seams (where behavior can be substituted).
   - Composition vs inheritance choices.
   - State ownership and side-effect locations.
3. Cross-check against curated intent and ADRs. Flag drift.

### Step 7 — Run analysis passes in order

Per the analysis order, run these passes **for each module in sequence**.
A finding produced by an earlier pass shadows a candidate finding for the
same code location in a later pass — do not double-file.

#### Pass 1 — Architecture

Apply:

- `references/aspects/architecture.md` (style-agnostic rules).
- The single matching `references/architectures/{style}.md` file.

Findings get `Aspect: Architecture` and a `Rule` from those files.

#### Pass 2 — SOLID

Apply `references/aspects/solid.md` per principle (SRP/OCP/LSP/ISP/DIP).
Skip findings that were already filed as Architecture (per cross-reference
rules inside `solid.md`).

#### Pass 3 — Clean Code

Apply `references/aspects/clean-code.md` per rule. Skip findings already
covered by Architecture or SOLID.

#### Pass 4 — Testability

Apply `references/aspects/testability.md` per rule. Skip findings whose
structural cause is filed above; only file pure testability symptoms.

### Step 8 — Run expansion checks

Before writing the module page, look for hidden coupling that changes findings or severity. Each item below must be checked — a finding's severity can only be finalized after this step:

- DI registrations and overrides
- factories and abstract factories
- partial classes / partial methods (.NET)
- extension methods crossing module boundaries
- reflection-based wiring
- source generators / compile-time code generation
- runtime configuration switching behavior
- tests revealing hidden invariants

Adjust findings and severities; record gaps in `known-gaps` if you cannot
verify.

### Step 9 — Write module pages

Use `references/wiki-page-template.md`. Each module page has:

- Frontmatter with `architecture-style`.
- Overview, Design (Recovered), Intent Alignment.
- `## Findings` section grouped by priority (Critical / Major / Minor) with
  findings within each priority ordered by aspect (Architecture → SOLID →
  CleanCode → Testability) per `references/output-format.md`.
- Accepted Trade-offs (ADR-backed deviations).
- Verification Notes and Design Insights.

### Step 10 — Identify and write cross-cutting design topics

After all module pages are drafted, scan them for recurring craft patterns. A
topic qualifies if it appears in ≥ 2 repositories OR ≥ 3 modules within one
repository.

Craft topic candidates are listed in `references/module-heuristics.md`
(Step 3 — Identify Cross-Cutting Design Topics, craft edition).

Each design topic page uses the same prioritized Findings layout as module
pages.

### Step 11 — Write generated index

Write `docs/craft-docs/index.md` with:

- `last-scan`, `repositories[]` with `name`, `path`, `architecture-style`, `last-commit-hash`
- module table with Critical/Major/Minor finding counts and confidence
- design topic table of contents
- links to consolidated reports

### Step 12 — Write consolidated reports

Each consolidated report groups by priority and lists findings as short
back-links to the module page where they live in full detail.

Write or refresh:

- `docs/craft-docs/reports/latest-refresh-summary.md`
- `docs/craft-docs/reports/architecture-findings.md`
- `docs/craft-docs/reports/solid-findings.md`
- `docs/craft-docs/reports/clean-code-findings.md`
- `docs/craft-docs/reports/testability-findings.md`
- `docs/craft-docs/reports/design-drift.md`
- `docs/craft-docs/reports/refactor-candidates.md`

Append run entry to:

- `docs/craft-docs/log.md`

### Step 13 — Verify

Run the Verification Checklist from `SKILL.md` and correct failures before
completion.

### Step 14 — Report outcome

Return a summary including:

- repositories discovered (with detected style each)
- modules analyzed
- design topics recovered
- ADRs incorporated
- curated files referenced
- findings by priority and aspect
- design-drift items
- known gaps and confidence caveats

---

## Part B — Update Mode

**Trigger:** `--update` flag passed, OR `docs/craft-docs/index.md` exists and `--init` was not passed.

The Update workflow is **change-driven**: it starts from the git delta,
maps changes to affected modules, classifies the change impact, and runs
only the analysis passes relevant to the change — extending scope only
when cascading effects are detected.

### Step 1 — Load prior metadata

Read `docs/craft-docs/index.md` frontmatter:

- previous `last-scan`
- `repositories[].last-commit-hash` and `repositories[].architecture-style`
- `related-adrs`

If a tracked repo is missing, warn and skip.
If a new repo appears on disk, treat it as new: run Init steps for that repo
and add it to index metadata.

### Step 2 — Re-read curated docs and ADRs

Always re-read `docs/craft-docs/curated/**/*.md`, even with no git changes.

Detect:

- New or updated style declarations (may change which architecture file
  applies).
- New ADRs (may downgrade existing findings to accepted trade-offs).
- Superseded ADRs (may re-raise previously accepted trade-offs as findings,
  with a `[CHANGE]` note in `design-drift.md`).
- New design notes (may shift drift status).

### Step 3 — Detect repository deltas

For each tracked repo:

```bash
cd {repo-path} && git log {last-commit-hash}..HEAD --name-only --format=
```

- Empty output: no code delta for that repo.
- If baseline hash is unreachable (rebased history), re-analyze the full
  repo.

### Step 4 — Map changed files to modules

Use module boundary heuristics to map changed files.

A module also becomes affected when:

- Curated/ADR changes touch it (findings may be downgraded or re-raised).
- The repo's `architecture-style` changed.
- A cross-cutting design topic page covering it gained or lost findings.

### Step 5 — Classify change impact and run targeted passes

For each affected module, classify the delta to determine the analysis
strategy:

| Change type | Classification | Action |
|---|---|---|
| New/removed classes, interfaces, or services | **Structural** | Full design recovery + all four passes (Step 5a) |
| Changed inheritance, DI wiring, or module boundaries | **Structural** | Full design recovery + all four passes (Step 5a) |
| Architecture style shift detected | **Structural** | Full design recovery + all four passes (Step 5a) |
| New/superseded ADR affecting this module | **Structural** | Full design recovery + all four passes (Step 5a) |
| Modified method bodies, logic changes within existing classes | **Incremental** | Targeted passes only (Step 5b) |
| Changed function signatures or return types | **Incremental** | Targeted passes only (Step 5b) |
| New/modified tests only | **Incremental** | Testability pass only (Step 5b) |
| Config, feature flags, or environment changes | **Incremental** | Architecture + affected passes (Step 5b) |

#### Step 5a — Full re-analysis (structural changes)

1. Re-read full module source.
2. Recompute slug.
3. Re-recover design.
4. Re-detect architecture style for the module (it may have shifted).
5. Run the four passes in order — Architecture → SOLID → CleanCode →
   Testability — exactly as in Init.
6. Re-run expansion checks.
7. Rewrite the module page completely.
8. Update any design topic page impacted by this module.

#### Step 5b — Targeted pass analysis (incremental changes)

1. Read the existing module page; extract current findings with their
   `First detected` dates and cited locations.
2. Determine which passes are affected by the change type:

   | Change pattern | Passes to re-run |
   |---|---|
   | Class/interface signature changes | SOLID (ISP, LSP) + CleanCode |
   | Method body logic changes | CleanCode + Testability |
   | New dependencies added | Architecture (dependency direction) + SOLID (DIP) |
   | Constructor changes | SOLID (SRP via injection count) + Testability |
   | Test file changes | Testability only |
   | Config/DI registration changes | Architecture only |
   | Naming/renaming | CleanCode only |

3. Re-read only the changed files and their immediate collaborators
   (direct callers/callees).
4. Run only the affected passes on the changed code area.
5. For each pass result:
   - **New finding:** Add it with `First detected` = now.
   - **Existing finding still present:** Preserve it with original
     `First detected`.
   - **Existing finding resolved:** Mark for removal from the page and
     consolidated reports (resolution recorded in log).
   - **Existing finding severity changed:** Update severity, preserve
     `First detected`.
6. Update only the Findings section of the module page. Preserve all other
   sections (Overview, Design Recovered, Intent Alignment, Accepted
   Trade-offs) verbatim unless a finding directly contradicts them.
7. Update page metadata: `generated-on` = now, `generated-from-commit` = HEAD.

#### Step 5c — Scope extension (cascading effects)

After running targeted passes, check for cascading effects:

- If a new Architecture finding is produced, check whether it shadows
  any existing SOLID or CleanCode finding for the same location (remove
  the shadowed finding).
- If a SOLID finding is resolved, check whether it was masking a
  CleanCode symptom that should now be filed.
- If the change affects a shared base class or interface, extend to
  other modules that depend on it (add them to the affected set).
- If a design topic page cites the changed code, update that topic page.

Track extensions to prevent infinite loops (each module processed at most
once per run).

### Step 6 — Update consolidated reports and finding lifecycle

For each `{aspect}-findings.md` report:

- Add new findings.
- Remove resolved findings (resolved = underlying code now passes the check,
  *or* a new ADR accepts it). Resolution is recorded only in `log.md` —
  the active report drops the entry.
- Preserve `First detected` on findings that persist.

For `design-drift.md`: add new items, remove resolved ones.

For `refactor-candidates.md`: recompute the prioritized list.

For `latest-refresh-summary.md`: overwrite with the new totals.

Append Update entry to `log.md` with new-vs-resolved counts per aspect.

### Step 7 — Update generated index metadata

Update in `docs/craft-docs/index.md`:

- `last-scan` = now (UTC ISO-8601)
- per-repo `last-commit-hash` and `architecture-style`
- Critical/Major/Minor counts per module in the module table
- `related-adrs` list reflecting current curated state

Update index body only when pages are added/removed/renamed.

### Step 8 — No-op guard

If no module/design/report content changed:

1. still update `last-scan` to reflect a completed scan,
2. append log entry,
3. report "No generated pages required updates."

### Step 9 — Report outcome

Return summary:

- repos checked / with changes / skipped
- modules updated: count (structural: N, incremental: N)
- passes re-run: breakdown by pass type and trigger
- scope extensions triggered: count and reason
- ADRs incorporated
- curated files reviewed
- new vs resolved findings by aspect and priority
- design-drift items added or resolved
- style changes observed
- no-op status if applicable

---

## Run Log Format

`docs/craft-docs/log.md` is append-only.

Header:

```markdown
# Craft Update Run Log

<!-- append-only: one entry per run, newest last -->
```

Init entry:

```markdown
## {ISO-8601 UTC timestamp} — Init
- Repos: {comma-separated repo names with style}
- Modules analyzed: {N}
- Design topics recovered: {N}
- ADRs incorporated: {N}
- Curated files incorporated: {N}
- Findings — total {N}:
  - Critical: {N} (Architecture: {N}, SOLID: {N}, CleanCode: {N}, Testability: {N})
  - Major:    {N} (Architecture: {N}, SOLID: {N}, CleanCode: {N}, Testability: {N})
  - Minor:    {N} (Architecture: {N}, SOLID: {N}, CleanCode: {N}, Testability: {N})
- Design-drift items flagged: {N}
```

Update entry:

```markdown
## {ISO-8601 UTC timestamp} — Update
- Repos checked: {N} ({N} with changes)
- Modules updated: {N} (structural: {N}, incremental: {N})
- Passes re-run: Architecture: {N}, SOLID: {N}, CleanCode: {N}, Testability: {N}
- Scope extensions: {N}
- Design topics updated: {N}
- ADRs incorporated: {N}
- Curated files incorporated: {N}
- Findings — delta:
  - Architecture: new {N} / resolved {N}
  - SOLID:        new {N} / resolved {N}
  - CleanCode:    new {N} / resolved {N}
  - Testability:  new {N} / resolved {N}
- Design-drift items flagged: {N}
- Style changes: {comma-separated repo: from → to, or "none"}
```

---

## Quality Guardrails

All guardrails are hard constraints — no exceptions.

| # | Constraint |
|---|---|
| 1 | Source code is the only authoritative proof. Curated docs declare intent; generated docs are orientation maps. Never cite either as runtime proof. |
| 2 | A finding without all required fields (priority, aspect, rule, file/line citation, evidence, suggested refactor, effort) must NOT be written. Omit it and record the gap in `known-gaps`. |
| 3 | Run passes in fixed order (Architecture → SOLID → CleanCode → Testability). File each finding to the earliest aspect that captures its root cause. |
| 4 | An ADR-accepted trade-off is never a violation. Record it under "Accepted Trade-offs" with the ADR citation instead. |
| 5 | Preserve `First detected` on persisting findings across Update runs. Never rewrite it. |
| 6 | Generated content must be high-value only: recovered design, prioritized findings with concrete refactors, accepted trade-offs, drift. No "looks fine" or restatement of obvious structure. |
| 7 | Record all uncertainty in `known-gaps` and `confidence`. Never silently assume completeness. |
