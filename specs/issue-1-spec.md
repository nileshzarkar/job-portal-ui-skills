# Technical Specification --- Issue #1

## 1. Issue Overview

| Field       | Value                                                                 |
| ----------- | --------------------------------------------------------------------- |
| Title       | Fix the typo in title `<title>JobPtal - Find Your Dream Job Today</title>` |
| Description  | The document `<title>` reads "JobPtal" and should read "JobPortal".   |
| Labels      | None                                                                  |
| State       | OPEN                                                                  |
| Assignee    | nileshzarkar                                                          |
| Priority    | Low (cosmetic / branding correction, no functional impact)            |

## 2. Problem Analysis

The HTML document title contains a spelling mistake. Verified in the repository:

- `index.html:10` → `<title>JobPtal - Find Your Dream Job Today</title>`

A single-line `grep` across the codebase confirms this is the **only** occurrence
of the misspelling `JobPtal`. The string drives the browser tab label, bookmark
text, and search-engine result title, so the typo is user-visible on every page
of this SPA (the title is set once in the static entry HTML).

Root cause: a plain text typo in the static entry point. No JavaScript, routing,
or React logic is involved.

## 3. Proposed Solution

Correct the misspelled word in the `<title>` tag.

- **Minimal change:** replace `JobPtal` with `JobPortal` on `index.html:10`.
- **Data flow:** none — the title is static markup, not derived state.
- **Trade-offs:** none. This is the smallest viable fix; no alternative design
  is warranted.

Final value:

```html
<title>JobPortal - Find Your Dream Job Today</title>
```

## 4. Step-by-Step Implementation

1. **Edit the title tag** — On `index.html:10`, change `JobPtal` to `JobPortal`,
   leaving the rest of the title (" - Find Your Dream Job Today") unchanged.
2. **Verify no other occurrences** — Re-run a search for `JobPtal` to confirm the
   typo does not exist elsewhere (already confirmed: only `index.html`).

## 5. Verification Strategy

### Unit Tests

- Not applicable — the project has no test runner configured, and a static title
  string does not warrant introducing one.

### Integration Tests

- Not applicable.

### Manual Checks

- Run `npm run dev`, open the app → the browser tab reads "JobPortal - Find Your
  Dream Job Today".
- `grep -rn "JobPtal"` returns no matches after the change.
- `npm run build` completes without error.

## 6. Files to Modify

| File Path    | Nature of Change                                    |
| ------------ | --------------------------------------------------- |
| `index.html` | Fix typo `JobPtal` → `JobPortal` in `<title>` (L10) |

## 7. New Files to Create

| File Path | Purpose         |
| --------- | --------------- |
| None      | No new files required |

## 8. Existing Utilities to Leverage

| Utility | Benefit                                  |
| ------- | ---------------------------------------- |
| None    | Direct one-token edit; no utility needed |

## 9. Acceptance Criteria

- The document title reads "JobPortal - Find Your Dream Job Today".
- No remaining occurrences of `JobPtal` in the codebase.
- No regressions: dev server and production build run unchanged.

## 10. Out of Scope

- Broader rebranding or renaming of "JobPortal" across components/pages.
- Adding per-route dynamic `<title>` management.
- Introducing a test framework.
