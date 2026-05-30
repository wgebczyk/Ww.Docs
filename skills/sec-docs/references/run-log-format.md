# SecDocs — Run Log Format

Append one entry to `docs/sec-docs/log.md` at the **end of every run** (after all
pages are written, before the Verification Checklist).

Create the file with this header if it does not yet exist:

```markdown
# SecDocs Run Log

<!-- append-only: one entry per run, newest last -->
```

**CONSTRAINT [HARD-WRITE]:** Never rewrite or truncate `log.md` — only append. Do
not embed this history in `index.md` or any category page.

## Init runs

```markdown
## {ISO-8601 UTC timestamp} — Init
- Repos: {comma-separated repo names}
- Categories documented: {N}
- Requirements assessed: {N}
- PASS: {N} | FAIL: {N} | PARTIAL: {N} | N/A: {N} | NOT-ASSESSED: {N}
- Curated files incorporated: {N}
- Top 10 items covered: {N}/10
- Entra ID audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
- Headers audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
- TLS audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
- Azure audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
- Deps audit: {run/not-run/not-applicable} | PASS: {N} FAIL: {N} WARN: {N}
```

## Incremental runs

```markdown
## {ISO-8601 UTC timestamp} — Incremental
- Repos checked: {N} ({N} with changes)
- Categories updated: {N} (by change mapping: {N}, by extension: {N})
- Requirements re-assessed: {N} (out of {total})
- Requirements preserved: {N}
- PASS: {N} | FAIL: {N} | PARTIAL: {N} | N/A: {N} | NOT-ASSESSED: {N}
- Status changes: {N} (list: V#.#.#: old → new, ...)
- Curated files incorporated: {N}
- Top 10 report regenerated: yes/no
- Entra ID audit: {incorporated new results/no new results}
- Headers audit: {incorporated new results/no new results}
- TLS audit: {incorporated new results/no new results}
- Azure audit: {incorporated new results/no new results}
- Deps audit: {incorporated new results/no new results}
```
