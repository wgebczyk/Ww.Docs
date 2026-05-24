# Aspect — Clean Code

Clean Code is the **third** analysis pass. Apply after Architecture and SOLID. Skip any finding whose root cause was already filed in an earlier pass.

**CONSTRAINT [HARD]:** Every finding uses the per-finding structure from `output-format.md` with `Aspect: CleanCode` and `Rule:` verbatim from the rule headings below.

**CONSTRAINT [HARD]:** Do NOT file `Boundary Leak` here — it belongs to `aspects/architecture.md`.

---

## Naming

**What it is:** Names reveal intent, are pronounceable and searchable, and are
free of disinformation or type-encoding noise.

**Detection heuristics:**

- Single-letter identifiers outside loop counters or math contexts (`d`,
  `tmp`, `data`, `info`).
- Type-encoded names (`strName`, `intCount`, `m_field`, Hungarian) where the
  language enforces types.
- Names whose meaning depends on hidden context (`Process()`, `Handle()`,
  `DoIt()`, `Run()`).
- Suffixes `Manager`, `Helper`, `Util`, `Service`, `Processor` *without
  qualifier*.
- Boolean members not phrased as questions (`status` for a flag where
  `isReady` was meant).
- Inconsistent vocabulary for the same concept (`fetch`/`get`/`load`/`retrieve`
  mixed within a module).

**False positives:**

- Loop counter `i`, lambda parameter `x` in a small scope.
- Domain abbreviations established by the team (`Iban`, `Vat`, `Pnr`). Confirm
  with a curated glossary if present.

**Severity:**

- **Critical** when a public, widely referenced symbol actively misleads
  readers (e.g. `Save` that also publishes events).
- **Major** when an internal name is vague or duplicates inconsistent
  vocabulary in the module.
- **Minor** when a local variable could be clearer in a short function.

**Before:**

```python
def process(data):           # process what? returns what?
    tmp = []
    for d in data:
        if d.s == 1:
            tmp.append(d)
    return tmp
```

**After:**

```python
def select_active_users(users: list[User]) -> list[User]:
    return [u for u in users if u.is_active]
```

---

## Function Size and Single Level of Abstraction

**What it is:** Functions are small, do one thing, and operate at a single
level of abstraction. Visible section comments inside a function are usually
extracted methods in disguise.

**Detection heuristics:**

- Function length > 30 non-trivial lines.
- Multiple `return` paths combined with nesting > 3 levels.
- A function mixes orchestration (named function calls) with low-level details
  (byte math, string slicing).
- Section comments `// validate`, `// then save` inside one function.
- Functions with > 5 parameters or > 3 boolean parameters.

**False positives:**

- Switch dispatchers over a closed set may legitimately be long.
- Configuration builders with fluent calls.
- Generated code — exclude under `known-gaps`.

**Severity:**

- **Critical** when a function spans > 100 lines or > 6 abstraction levels and
  readers cannot summarize it in one sentence.
- **Major** at 40-100 lines or 3-4 abstraction levels.
- **Minor** when moderately long but coherent.

**Before:**

```csharp
public void HandleOrder(OrderRequest req)
{
    // validate
    if (req.Items == null || req.Items.Count == 0) throw new ...;
    foreach (var i in req.Items) { if (i.Qty <= 0) throw new ...; }

    // map
    var order = new Order { ... };
    foreach (var i in req.Items) order.Lines.Add(new Line { ... });

    // persist
    using var conn = new SqlConnection(...);
    conn.Execute("INSERT ...", order);
    foreach (var l in order.Lines) conn.Execute("INSERT ...", l);

    // notify
    _bus.Publish(new OrderCreated(order.Id));
}
```

**After:**

```csharp
public void HandleOrder(OrderRequest req)
{
    OrderValidator.EnsureValid(req);
    var order = OrderMapper.From(req);
    _orderRepository.Save(order);
    _bus.Publish(new OrderCreated(order.Id));
}
```

---

## Comments

**What it is:** Comments explain *why* for non-obvious decisions. They don't
narrate *what* the code does, leave dead code lying around, or rot in place
while the code below them changes.

**Detection heuristics:**

- Comments paraphrasing the next line of code.
- Commented-out code blocks.
- TODO/FIXME/XXX older than 1 year (use git blame if available).
- Boilerplate file headers with copyright + author + date nobody maintains.
- Doc comments that disagree with the function signature.

**False positives:**

- Comments explaining a non-obvious workaround, regulatory requirement, or
  subtle invariant are *good* — do not flag.
- License headers required by policy.

**Severity:**

- **Critical** when a comment actively misleads readers — following it would
  introduce a bug.
- **Major** when commented-out code blocks span > 5 lines, or stale TODOs are
  > 1 year old in non-trivial code paths.
- **Minor** when comments are redundant but not misleading.

**Before:**

```python
# Increment counter by one
counter = counter + 1

# Old logic — keep just in case
# if user.role == "admin":
#     return True
return user.is_authorized()
```

**After:**

```python
counter += 1

return user.is_authorized()
```

---

## Duplication

**What it is:** Don't repeat knowledge that has a single source of truth.
Watch also for *accidental* duplication — code that looks similar but encodes
different decisions, which DRY would wrongly couple.

**Detection heuristics:**

- Same conditional logic in > 2 sites with no shared helper.
- Magic literals (URLs, regex, error codes) appearing in > 2 files.
- Two near-identical classes differing only in a type parameter.
- Repeated per-pair mapper code (`AdtoB`, `BtoA`) when a general pattern
  exists.

**False positives:**

- Two tests asserting different scenarios that look similar — readability >
  DRY in tests.
- Framework boilerplate (controller attribute stacks, config builders).

**Severity:**

- **Critical** when duplicated logic encodes a business rule and an update to
  one site without the others would cause silent incorrectness.
- **Major** when duplication is stylistic but encodes the same intent.
- **Minor** when surface similarity exists without shared meaning (consolidate
  only with caution — risk of false coupling).

**Before:**

```typescript
// in three different routes
const MAX_AGE = 60 * 60 * 24 * 7; // 7 days
res.cookie("session", token, { maxAge: MAX_AGE });
```

**After:**

```typescript
// auth/cookie-options.ts
export const SESSION_COOKIE_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

// in routes
import { SESSION_COOKIE_MAX_AGE_MS } from "auth/cookie-options";
res.cookie("session", token, { maxAge: SESSION_COOKIE_MAX_AGE_MS });
```

---

## Complexity and Nesting

**What it is:** Keep cyclomatic complexity and nesting low. Prefer guard
clauses, early returns, and small functions over deeply nested conditionals.

**Detection heuristics:**

- Nesting depth > 3 inside a function body.
- > 10 decision points in one function (`if`/`else if`/`case`/`&&`/`||`/`?:`/`?.`/`catch`).
- Loop bodies > 20 lines.
- Boolean expressions joining > 4 sub-expressions without naming intermediates.

**False positives:**

- State machines as switch-on-state are expected to have many cases.

**Severity:**

- **Critical** when nesting > 5 or complexity > 20 and reviewers consistently
  misread the function.
- **Major** at nesting 4-5 or complexity 11-20.
- **Minor** when borderline but well-named and well-tested.

**Before:**

```csharp
public Result Process(Request r)
{
    if (r != null)
    {
        if (r.IsValid)
        {
            if (r.User != null)
            {
                if (r.User.IsActive)
                {
                    return DoWork(r);
                }
            }
        }
    }
    return Result.Error;
}
```

**After:**

```csharp
public Result Process(Request r)
{
    if (r is null)            return Result.Error;
    if (!r.IsValid)           return Result.Error;
    if (r.User is null)       return Result.Error;
    if (!r.User.IsActive)     return Result.Error;
    return DoWork(r);
}
```

---

## Magic Numbers and Strings

**What it is:** Replace literals with named constants when the literal encodes
a business or technical decision.

**Detection heuristics:**

- Numeric literals other than `0`, `1`, `-1`, `2` inline in business logic.
- Repeated string literals used as keys, type discriminators, or labels.
- Time durations as raw numbers (`Sleep(3600)`).
- HTTP status codes inline (`200`, `404`) instead of named constants.

**False positives:**

- Test data where the literal *is* the spec.
- Empirically tuned hash/cache sizes with a one-line why-comment.

**Severity:**

- **Critical** when the literal encodes a business rule changing with
  regulation/pricing and appears in > 2 files.
- **Major** when local to one function but opaque without comments.
- **Minor** when the literal is itself the spec.

**Before:**

```java
if (account.getBalance() < 100) {        // why 100?
    throw new InsufficientFundsException();
}
```

**After:**

```java
private static final BigDecimal MIN_WITHDRAWAL_BALANCE = new BigDecimal("100.00");

if (account.getBalance().compareTo(MIN_WITHDRAWAL_BALANCE) < 0) {
    throw new InsufficientFundsException();
}
```

---

## Error Handling

**What it is:** Errors are either handled, transformed at a meaningful
boundary, or propagated. Catch-and-swallow, control-flow-by-exception, and
overly broad `try` blocks are violations.

**Detection heuristics:**

- `catch` blocks that log and continue without re-throwing.
- `catch (Exception)` / bare `except:` / `catch (Throwable)` without rationale.
- Exceptions signaling expected outcomes in a hot path
  (`EntityNotFoundException` when "not found" is common).
- `try` blocks > 30 lines obscuring which call throws.
- Nullable returns mixed with exception throws for the same condition across
  the codebase.
- Empty catch blocks.

**False positives:**

- Top-level error boundaries (`Main`, request middleware, message-pump root)
  are expected to catch broadly and log.
- Best-effort cleanup in `finally` may swallow secondary failures.

**Severity:**

- **Critical** when an exception is swallowed in a path affecting business
  outcome — failure becomes invisible.
- **Major** when a broad catch has partial recovery without logging, or
  expected outcomes are modeled as exceptions in hot paths.
- **Minor** when a broad catch sits at a process boundary with proper logging
  but isn't strictly necessary.

**Before:**

```python
def update_user(user_id, data):
    try:
        user = db.get_user(user_id)
        user.update(data)
        db.save(user)
        send_notification(user)
    except Exception:
        pass   # silent swallow
```

**After:**

```python
def update_user(user_id, data):
    user = db.get_user(user_id)         # raises UserNotFound — caller handles
    user.update(data)
    db.save(user)
    try:
        send_notification(user)
    except NotificationError as e:
        log.warning("notification failed for %s: %s", user_id, e)
        # notification failure does not roll back the update
```

---

## Dead Code

**What it is:** Remove unused code. Source control preserves history.

**Detection heuristics:**

- Public types/methods with no production references (callers only in tests).
- Conditional branches that can never be entered (constant-false conditions).
- Feature-flag branches whose flag has been permanently flipped.
- Old API versions retained without deprecation notice.

**False positives:**

- Public library API surface unused inside the repo but exported to consumers.
- Reflection / DI / serialization frameworks may consume types invisibly —
  verify before flagging.

**Severity:**

- **Major** when dead code is sizeable (> 100 lines) and crowds the module, or
  when developers extend or call it thinking it's used.
- **Minor** when it's a small unused helper or stale parameter.

> **Critical** is unusual for dead code in isolation — escalate only if the
> dead code is a security-relevant path that could be re-enabled by mistake.

**Before:**

```csharp
public class ReportService
{
    public Report Generate(...) { ... }

    [Obsolete] // never marked, never removed
    public Report GenerateLegacy(...) { ... }   // last caller deleted in 2022
}
```

**After:**

```csharp
public class ReportService
{
    public Report Generate(...) { ... }
}
```

---

## Output Rules

- Use the per-finding structure from `output-format.md`.
- `Aspect: CleanCode` and `Rule:` is one of the headings above verbatim.
- If the same code triggers an Architecture or SOLID rule, file it there per
  the analysis order. Do not duplicate.
- If a curated ADR accepts a deviation (e.g. "DTOs may have > 7 fields"),
  record it under "Accepted Trade-offs" on the module page and do not write a
  finding.
