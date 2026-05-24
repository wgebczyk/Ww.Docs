# Ww.Docs

A set of Agentic Coder skills for generating and maintaining structured documentation directly from source code.

## Skills

| Skill | Purpose |
|---|---|
| `craft-docs` | Code craftsmanship analysis: Architecture, SOLID, Clean Code, Testability |
| `sec-docs` | OWASP ASVS v5 security compliance documentation |
| `tech-docs` | Codebase knowledge base: modules, design topics, mismatches |

Each skill comes in two forms:

- **skill** - operates across all git repositories found at the workspace root
- **skill-mini** - the same skill scoped to a single repository (current working directory)

The "mini" form is identical in rules and output structure. The only differences are scope (one repo instead of many), module slug format (no repo-name prefix), and the absence of Azure pipeline generation.

## Common Flags

| Flag | Effect |
|---|---|
| `--init` | Force full initialization |
| `--update` | Force incremental update |
| `--all` | Re-analyse everything, ignoring change detection |

## Output

All skills write under `docs/<skill-name>/` within each repository. Curated docs (`docs/<skill-name>/curated/`) are human-owned and read-only for the skill.
