---
name: tech-docs
description: >
  Use this skill when the user asks to generate or refresh codebase knowledge docs,
  update the wiki, run a mismatch report, or invoke /tech-docs. Follows a hybrid
  strategy: curated docs define intent, generated docs summarize structure, source
  code verification establishes actual behavior.
allowed-tools:
  - readFile
  - createFile
  - writeFile
  - search
  - fileSearch
  - 'shell:git'
  - 'shell:Get-ChildItem'
  - 'shell:New-Item'
---

# TechDocs Skill

Generates and incrementally maintains a structured, cited, interlinked knowledge base
under `docs/tech-docs/` from all git repositories discovered at the workspace root.
Curated docs declare intent; generated docs summarize observed structure; source code
is the only proof of actual behavior.

## Core Principle

**RULE:** Curated docs define intent. Generated docs summarize observed structure. Source code proves actual behavior — never assert how code works without verified evidence.

**CONSTRAINT [HARD]:** Every substantive technical claim requires a source citation — file path and, where localized, line range. Never propagate curated intent as verified fact.

## Mode Detection

Determine mode before any other work. Flags take precedence over file-state detection.

| Condition | Mode |
|---|---|
| `--init` flag passed | **Init** — if `index.md` already exists, report which pages will be overwritten before proceeding |
| `--update` flag passed | **Update** |
| No flag; `docs/tech-docs/index.md` does not exist | **Init** |
| No flag; `docs/tech-docs/index.md` exists | **Update** — read YAML frontmatter, extract `last-scan` and `repositories[].last-commit-hash` |

For pipeline generation flags, see Pipeline Generation.

## Pipeline Generation

The pipeline YAML is generated from `references/azure-pipeline-template.yml` and written to `docs/tech-docs/azure-pipeline.yml`.

**When to generate:**

| Context | Behaviour |
|---|---|
| `TF_BUILD` environment variable is set (running inside Azure Pipelines) | Skip — never generate from within a pipeline |
| Interactive, Init mode, file does not yet exist | Generate automatically |
| Interactive, file already exists or Update mode | Skip unless `--gen-pipeline` is passed |

Passing `--gen-pipeline` forces generation and overwrites any existing file. Use it when new repositories have been added.

**Placeholder substitution** (replace every token in the template):

| Placeholder | Value |
|---|---|
| `{GENERATED_DATE}` | Today's date (ISO-8601) |
| `{DOCS_REPO_NAME}` | Workspace root directory name |
| `{REPO_N_NAME}` | Repository directory name for repo N |
| `{REPO_N_ALIAS}` | camelCase of repo name (remove hyphens, uppercase next char — e.g. `crackling-api` → `cracklingApi`) |

For repositories beyond the two shown in the template, replicate the `resources.repositories` entry and the corresponding `checkout` step for each additional repo.

## Flags

| Flag | Effect |
|---|---|
| `--init` | Force Init mode. If `index.md` already exists, report which pages will be overwritten before proceeding. |
| `--update` | Force Update mode. |
| `--all` | In Update mode, re-process all modules and design topics regardless of what changed (bypass change-to-module mapping). Use when you suspect cross-cutting impact or want a full knowledge refresh without re-running Init. |
| `--gen-pipeline` | Force pipeline generation and overwrite any existing `azure-pipeline.yml`. Use when new repositories have been added. |

## Write Constraint

Only these paths are writable:

- `docs/tech-docs/index.md` — agent-owned hub index, updated each run
- `docs/tech-docs/log.md` — append-only run log; never rewrite or truncate
- `docs/tech-docs/pages/` — agent-owned, periodically refreshed knowledge pages
- `docs/tech-docs/reports/` — agent-owned run outputs (mismatches, summaries, risk reports)
- `docs/tech-docs/azure-pipeline.yml` — created on first Init; overwritten only when `--gen-pipeline` is explicitly passed

`docs/tech-docs/curated/` is human-owned and read-only for the agent (durable intent,
invariants, ADRs). All other paths are read-only. If a write would target any other
path, stop and report the violation.

## Module Naming Rules

Slug format: `{repo-name}-{module-name}` in lowercase kebab. If the repo name's last
segment equals the module name's first segment, remove the duplicate
(e.g. `crackling-api` + `api-host` → `crackling-api-host`).

## Citation Rules

Every factual claim about code must be followed by a source reference:

```
(source: repo-name/path/to/file.ext)
```

Paths are relative to the workspace root. If two sources contradict each other,
write both citations and flag the conflict:

```
[CONFLICT: repo-a/file.cs says X; repo-b/other.ts says Y]
```

**CONSTRAINT [HARD]:** Never make unsourced claims about how the code works.

## Curated Docs Integration

Before any code analysis, read all files matching `docs/tech-docs/curated/**/*.md`.
If the directory does not exist, continue with generated-only flow and report this gap.

For each curated file:

1. Note its filename stem and check for a `module:` or `topic:` YAML frontmatter field.
2. Treat it as intent-level context, not runtime proof.
3. In corresponding generated pages, reference curated assumptions with
   `(source: docs/tech-docs/curated/filename.md)`.
4. If source code disagrees, add `[NOTE: curated says X; code shows Y — verify with team]`
   in the generated page and record the mismatch in
   `docs/tech-docs/reports/doc-code-mismatches.md`.
5. When a curated doc explicitly states an intentional design decision, do not flag it as
   a mismatch — cite the curated doc and record under "Accepted Trade-offs" on the module page.
6. Re-read `docs/tech-docs/curated/` on every run — the user may have updated curated docs
   between git commits.

## Verification-First Answer Protocol

When answering analysis prompts with this skill:

1. Read relevant curated and generated pages.
2. Extract assumptions, flows, invariants, and likely risk points.
3. Translate assumptions into hypotheses.
4. Verify hypotheses in current source code from a narrowed scope.
5. Expand search to hidden paths: background jobs, event handlers, flags,
   configuration, tests, migrations, legacy scripts, and alternate entry points.
6. Answer based on verified code behavior.
7. Call out mismatches, uncertainty, and suggested doc updates.

**CONSTRAINT [HARD]:** For security, data handling, authorization, financial logic,
compliance, and other high-risk topics, source verification is mandatory before
final conclusions. Never propagate curated intent as verified fact.

## Run Log

At the **end of every run** (after all pages are written, before the Verification
Checklist), append one entry to `docs/tech-docs/log.md`. Create the file with a
header if it does not yet exist:

```markdown
# Knowledge Update Run Log

<!-- append-only: one entry per run, newest last -->
```

For **Init** runs:
```markdown
## {ISO-8601 UTC timestamp} — Init
- Repos: {comma-separated repo names}
- Modules created: {N}
- Design topics: {N}
- Curated files incorporated: {N}
- Mismatches flagged: {N}
```

For **Update** runs:
```markdown
## {ISO-8601 UTC timestamp} — Update
- Repos checked: {N} ({N} with changes)
- Modules updated: {N} (structural: {N}, incremental: {N})
- Design topics updated: {N}
- Curated files incorporated: {N}
- Scope extensions triggered: {N} (within-module: {N}, cross-module: {N})
- Mismatches flagged: {N}
```

**CONSTRAINT [HARD]:** Never rewrite or truncate `log.md` — only append. Do not embed
this history in `index.md` or any wiki page. `log.md` is excluded from template and
citation requirements.

## Verification Checklist

Run these checks before reporting completion.

**Structure and Metadata**
- [ ] `docs/tech-docs/index.md` exists and has valid metadata
- [ ] Every link in `index.md` resolves to an existing file
- [ ] Every generated page has required sections from the template
- [ ] Every generated page includes `generated-on`, `generated-from-commit`,
      `generated-from-branch`, `source-paths-analyzed`, `related-curated-docs`,
      `known-gaps`, `confidence`, `source-repos`
- [ ] Repositories tracked in `index.md` match repos found on disk
- [ ] Each `last-commit-hash` matches `cd {path} && git log -1 --format=%H`

**Content Quality**
- [ ] Every substantive claim has at least one `(source: ...)` citation
- [ ] Every curated file is cited by at least one generated page or listed in known gaps
- [ ] `docs/tech-docs/reports/doc-code-mismatches.md` exists and lists mismatches or
      states none found

**Naming**
- [ ] Every module page slug follows `{repo-name}-{module-name}` lowercase kebab with
      de-duplication applied

**Reports**
- [ ] `docs/tech-docs/reports/latest-refresh-summary.md` exists
- [ ] `docs/tech-docs/log.md` has a new entry for this run

For Update runs, also check:
- [ ] New `last-scan` timestamp is later than previous
- [ ] Only affected module/design pages have updated `generated-on`
- [ ] Unchanged sections within updated pages are preserved verbatim

**Pipeline** (only when pipeline was generated this run)
- [ ] `docs/tech-docs/azure-pipeline.yml` exists
- [ ] File contains no unsubstituted `{PLACEHOLDER}` tokens
- [ ] One `resources.repositories` entry and one `checkout` step exist per discovered repo

## Init Workflow

Load `references/init-workflow.md` — depth standard and step-by-step procedure.

## Update Workflow

Load `references/update-workflow.md` — step-by-step procedure.

## Reference Files

Load these as needed — they are not in context by default:

| File | Load when |
|---|---|
| `references/init-workflow.md` | Starting Init mode |
| `references/update-workflow.md` | Starting Update mode |
| `references/workflow-guide.md` | Full procedural detail for either mode |
| `references/module-heuristics.md` | Identifying modules or design topics |
| `references/wiki-page-template.md` | Writing or updating any wiki page |
| `references/azure-pipeline-template.yml` | Generating the pipeline YAML |
