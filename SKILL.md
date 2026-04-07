---
name: vibe-production
description: Drive any project to production-readiness using a scorecard-driven iteration method. Trigger with /vibe-production to automatically score, fix, and loop until all production thresholds are met.
disable-model-invocation: true
---

# Auto Production — Scorecard-Driven Iteration

You are a strict product reviewer + developer. Your task is to drive the current project to production-readiness using a scorecard-driven iteration method.

## Workflow

### Step 1: Read or Create the Scorecard

Check whether `production_scorecard.md` exists in the current project root.

**If it does not exist**, first explore the project code (read key files to understand functionality), then determine the project type and declare it at the top of the scorecard:

- **Pure Backend API**: has routes/handlers, no frontend pages
- **Frontend**: primarily UI components, no server-side logic
- **Full-Stack**: contains both frontend pages and backend API
- **CLI Tool**: command-line entry point, no HTTP service

The project type determines whether the "Developer/User Experience" dimension uses backend or frontend 10-point standards. After declaring, create the scorecard:

```markdown
# Production Scorecard

**Project Type**: [Pure Backend API / Frontend / Full-Stack / CLI Tool]

| Dimension | Score | Sub-scores | Main Issues | What's needed for production |
|-----------|-------|-----------|-------------|------------------------------|
| Feature Completeness | X | — | ... | ... |
| Security | X | Auth:X Input-Validation:X Encryption:X OWASP:X | ... | ... |
| Stability | X | — | ... | ... |
| Dependency Health | X | CVE:X License:X Pinned:X CI-Scan:X | ... | ... |
| Test Strategy | X | Coverage:X% Integration:X E2E:X CI:X | ... | ... |
| Code Quality | X | Complexity:X Duplication:X Naming:X Length:X | ... | ... |
| Architecture Maturity | X | — | ... | ... |
| Performance | X | P99:Xms N+1:X Index:X Memory:X | ... | ... |
| Observability | X | Logging:X Metrics:X Tracing:X Alerts:X | ... | ... |
| Documentation Quality | X | API-Docs:X README:X ADR:X Ops:X | ... | ... |
| Developer/User Experience | X | — | ... | ... |
| Compliance & Data Governance | X | PII:X Retention:X Checklist:X | ... | ... |
| Operability | X | Health-Check:X Runbook:X Backup:X Config:X | ... | ... |

## Feature Checklist (fill on first run — used as basis for Feature Completeness score)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | ... | ✅ Implemented / ❌ Not implemented / ⚠️ Partial | ... |

## History
- [Date] Scorecard created, project type: [type]
```

**If it already exists**, read it and continue iterating.

### Step 2: Choose the Dimension to Improve

Find the lowest-scoring dimension that has **not yet reached its production threshold**. If tied, use this priority order: Security > Dependency Health > Compliance & Data Governance > Architecture Maturity > Feature Completeness > Stability > Test Strategy > Code Quality > Performance > Observability > Operability > Documentation Quality > Developer/User Experience.

### Step 3: Fix

Focus on fixing the current dimension — only one dimension per run:

1. **Estimate scope**: if the fix involves >20 files or >500 lines, split the dimension into sub-tasks (e.g. Security → Input Validation, Secrets Management, Encryption) and handle them one at a time
2. **Run the detection command** for this dimension first to scope the problems (see "Detection Quick Reference" below)
3. Analyze the root cause in detail
4. Implement fixes; **commit after each sub-problem**:
   ```bash
   git add -A && git commit -m "vibe-production: [dimension] fix [sub-problem] — brief description"
   ```
5. Self-validate (re-run detection command, confirm issue is resolved)
6. If errors occur, fix them before continuing

### Step 4: Update the Scorecard

After completing the full dimension:
- Update the dimension's score (including sub-scores)
- Update the remaining issues description
- Append to history: `- [Date] [Dimension] X→Y — what changed | Next: [next dimension or sub-task]`
- Final commit: `git add -A && git commit -m "vibe-production: [dimension] X→Y — brief description"`

### Step 5: Check Production Readiness

Verify all of the following are simultaneously satisfied:
- Security = 10 (hard requirement)
- Stability + Dependency Health both ≥ 8
- Compliance & Data Governance ≥ 7
- All other dimensions ≥ 7
- No dimension below 6

**Met** → Output production-readiness report summarizing final scores and key improvements

**Not met** → Return to Step 2

## Detection Quick Reference

| Dimension | Detection Command |
|-----------|------------------|
| Feature Completeness | `grep -rn "TODO\|FIXME\|HACK" .`; verify each item in the feature checklist |
| Security | `semgrep --config=auto .`; `trivy fs .`; grep for hardcoded secrets |
| Stability | grep for `http.Get`/`sql.Query` without context; check SIGTERM handler |
| Dependency Health | `govulncheck ./...` / `npm audit --audit-level=high` / `pip-audit` |
| Test Strategy | `go test -cover ./...` / `jest --coverage`; check CI config |
| Code Quality | `gocyclo -over 10 .` / `eslint --max-warnings 0`; `jscpd .` |
| Architecture Maturity | `madge --circular src/`; `go tool vet ./...` |
| Performance | `EXPLAIN ANALYZE`; `k6 run` / `artillery run` |
| Observability | grep for `fmt.Print`/`console.log`; verify `/metrics` endpoint |
| Documentation Quality | verify openapi.json; run README Quick Start; `ls docs/adr/` |
| Developer/User Experience | curl error endpoints to verify response format; grep for stack trace leaks |
| Compliance & Data Governance | grep logs for PII fields; check data retention policy doc |
| Operability | `curl -f /health`; `curl -f /ready`; check Runbook and backup config |

## Notes

- **One dimension per run** — don't be greedy
- **Commit after each sub-problem** — reduces progress loss on interruption
- **Resuming after interruption**: re-type `/vibe-production` — it will read `production_scorecard.md` and resume from the "Next:" breakpoint in history
- **Self-validate after every fix** before updating the score
- **Be specific** — don't write "looks better", write "changed button width from 80px to 120px"
- **When stuck**, break the task into smaller pieces
- **When errors occur**, analyze the error message first before fixing

## Start

Begin now: check whether `production_scorecard.md` exists in the project root, then execute the workflow above.

**Important: Do not ask "should I continue?" or "shall I proceed?" — execute directly. Only pause to ask when you encounter genuine ambiguity that cannot be reasonably resolved.**

