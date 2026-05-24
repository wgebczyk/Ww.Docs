# Output Format

Every finding produced by this skill — across architecture, SOLID, clean code,
and testability — is reported as a **prioritized list**, never as flat free
text. This file defines the priority taxonomy, the per-finding structure, and
the layout used by module pages and consolidated reports.

---

## Priority Levels

| Level | Criteria |
|---|---|
| **Critical** | At least one of: (1) compromises an architectural boundary or invariant; (2) creates production data/safety/correctness risk; (3) blocks testability for a system seam; (4) growth pressure — every new feature makes the issue rapidly worse. |
| **Major** | Locally painful: costs feature development time, hurts onboarding, forces test smells, or requires defensive code in callers. Not yet a boundary risk. |
| **Minor** | Stylistic or isolated. No growth pressure. Cleanup is straightforward, contained to one file or function, and a reasonable team could defer it. |

Priorities are **Critical / Major / Minor**. Do not use "High / Medium / Low",
"P0 / P1 / P2", or numeric scores in output. The mapping is one-way: rule
rubrics inside aspect files describe when a violation rises to Critical, when
it stays Major, when it falls to Minor.

A finding without a justified priority is not allowed. Pick the lowest level
that still satisfies the criteria above.

---

## Per-Finding Structure

Every finding — in a module page or in a consolidated report — must use this
shape:

```markdown
### [{Critical|Major|Minor}] {Short title in imperative form}

- **Aspect:** {Architecture | SOLID | CleanCode | Testability}
- **Rule:** {specific rule name, e.g. SRP, Function Size, Hidden Dependency, Boundary Leak}
- **Where:** `repo/path/file.ext:L{start}-L{end}` (one or more)
- **Evidence:** one-paragraph description (≤ 3 sentences) of what the code does
  and why it violates the rule.
- **Suggested refactor:** concrete change in 1-3 sentences. Name the target
  shape. Pick one option — do not offer alternatives in the report.
- **Effort:** S | M | L
- **First detected:** {ISO date — Init run for new findings; preserved across Update runs}
```

Field rules:

- **Short title** is imperative ("Extract billing policy from CommandHandler"),
  not descriptive ("CommandHandler is too big").
- **Aspect** is one of the four. No mixing.
- **Rule** comes from the aspect file's rule headings — verbatim.
- **Where** must include at least one file path; line range is required when the
  finding is localized.
- **Evidence** must reference code with a citation if not already in `Where`.
  No speculation. No "this looks like…".
- **Suggested refactor** must name the destination pattern ("Introduce
  `IBillingPolicy` and inject it into `CommandHandler`"). No "consider
  refactoring", no "may want to extract", no menu of options.
- **Effort:** S = under a day, M = a few days, L = a week or more. If you can't
  estimate, write `M` and add a brief reason in evidence.
- **First detected** lets refactor planning track age. Update runs preserve
  this date on findings that persist.

---

## Report Layout

Every container of findings — module page or consolidated report — groups by
priority:

```markdown
## Critical

### [Critical] {title 1}
…
### [Critical] {title 2}
…

## Major

### [Major] {title 3}
…

## Minor

### [Minor] {title 4}
…
```

Within a priority level, **order findings by aspect** in this fixed sequence:

1. Architecture
2. SOLID
3. CleanCode
4. Testability

This matches the analysis order in `SKILL.md` and makes structural issues
visible before surface issues at every priority.

Empty priority sections must still be shown:

```markdown
## Critical

_No critical findings at current depth._
```

---

## Suggested-Refactor Wording

The "Suggested refactor" field must:

- **Name the destination pattern.** Examples: "Extract Strategy", "Introduce
  Port `IClock`", "Move validation into application service", "Replace switch
  with polymorphism via `IRateCalculator`".
- **Stay within 3 sentences.**
- **Not present options.** No "consider A, B, or C". The skill picks one.
- **Not say "consider refactoring" without specificity.** "Consider extracting
  the validation logic" is not allowed. "Extract validation into a
  `ReservationValidator` invoked before the command handler runs" is.
- **Not promise testing/CI changes** unless the refactor structurally requires
  it. The skill reports craft, not delivery process.

---

## File and Line References

`Where` field rules:

- Format: `repo-name/relative/path/file.ext:Lstart-Lend`
- Multiple locations are listed on separate bullets when a finding spans files:
  ```markdown
  - **Where:**
    - `cold-wave-api/src/Billing/CommandHandler.cs:L42-L88`
    - `cold-wave-api/src/Billing/Validator.cs:L15-L33`
  ```
- If the finding is module-wide (e.g. consistent boundary leak across many
  files), point at the module root and list 2-3 exemplars under Evidence.
- Line ranges are inclusive. If the violation is a single line, use
  `:L42-L42` — not `:L42`.

---

## Consolidated Reports vs Module Pages

The same finding may appear in two places:

1. **Module page** (`pages/modules/{slug}.md`) — primary, full structure.
2. **Consolidated report** (`reports/{aspect}-findings.md` or
   `reports/refactor-candidates.md`) — shorter shape, links back to module page.

In consolidated reports, replace **Evidence** + **Suggested refactor** + **Effort**
with a single line and a back-link:

```markdown
### [Critical] Extract billing policy from CommandHandler

- **Aspect:** SOLID — SRP
- **Where:** `cold-wave-api/src/Billing/CommandHandler.cs:L42-L88`
- **Details:** [cold-wave-api-billing](../pages/modules/cold-wave-api-billing.md#critical)
```

The full structure lives in one place to avoid drift between page and report.

---

## Anti-patterns in Reporting

Findings that violate any of the following must not be written:

- No citation, or citation pointing only at a directory.
- Severity word without justification ("This is High because the code is ugly").
- Mixed aspects in one finding ("SRP and DIP and naming all collapse here").
  Split into separate findings.
- Catch-all "general cleanup needed" findings.
- Findings that restate structure without identifying a rule violation.
- Findings about hypothetical future requirements ("if we ever add X this will
  hurt"). The skill reports observed problems, not predictions.

If you cannot meet these requirements, record the gap in the page's
`known-gaps` frontmatter and do not write the finding.
