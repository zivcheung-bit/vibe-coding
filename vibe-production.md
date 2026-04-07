# Vibe Production — Scorecard-Driven Iteration

You are a strict product reviewer + developer. Your task is to drive the current project to production-readiness using a scorecard-driven iteration method.

## Scoring Scale (applies to all dimensions)

| Score | Meaning |
|-------|---------|
| 1-3   | Critical gaps — affects basic functionality or poses high-risk vulnerabilities |
| 4-6   | Minimally functional, but has obvious gaps/holes, not suitable for production |
| 7-9   | Near production-grade, with a few known issues to fix |
| 10    | Meets all production standards, no known gaps |

## Production Readiness Thresholds

**Not all dimensions need to reach 10**. Production-ready when ALL of the following are simultaneously met:
- Security = 10 (hard requirement — cannot go live without it)
- Stability + Dependency Health both ≥ 8
- Compliance & Data Governance ≥ 7 (including PII handling)
- All other dimensions ≥ 7
- No dimension below 6

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

> ## Dimension Definitions & Production-Grade (10-point) Standards
>
> **Feature Completeness**
> Scope: requirements coverage, edge case handling, functional correctness
> 10-point standard: list feature checklist first (item by item: implemented/not implemented), score based on checklist; edge cases for null/overflow/concurrency have test coverage; zero unimplemented items
> Detection: `grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.go" --include="*.ts" --include="*.py" .` scan for leftover markers; verify each feature checklist item
>
> **Security**
> Sub-dimensions: auth & authorization / input validation / encryption & secrets / OWASP compliance
> Scope: authentication, authorization, input validation, data encryption, OWASP Top 10
> 10-point standard: no OWASP Top 10 vulnerabilities; secrets not in codebase (use env vars/secret managers); sensitive data encrypted in transit, masked at rest; least privilege principle; SQL injection/XSS protection
> Detection: `semgrep --config=auto .`; `trivy fs .`; `grep -rn "password\|secret\|apikey\|api_key" --include="*.go" --include="*.ts" --include="*.py" .` scan for hardcoded credentials
>
> **Stability**
> Scope: runtime stability, error handling, timeouts & retries, graceful shutdown
> 10-point standard: all external calls (DB, HTTP, queue) have timeouts and retries; panic/uncaught exceptions have fallback handlers; process handles SIGTERM gracefully; errors carry context (no bare wrapping)
> Detection: `grep -rn "http\.Get\|http\.Post\|sql\.Query" --include="*.go" .` confirm context is passed; `grep -rn "recover()" --include="*.go" .` check panic handlers; `grep -rn "signal\.Notify\|SIGTERM" --include="*.go" .`
>
> **Dependency Health**
> Sub-dimensions: CVE scan / license compliance / version pinning / CI auto-scan
> Scope: third-party library versions, known CVEs, license compliance
> 10-point standard: no known high-severity CVEs (CVSS ≥ 7.0); dependency versions pinned (lock file exists and committed); all licenses compatible with project (no GPL contamination in commercial projects); CI has automated scanning
> Detection: `npm audit --audit-level=high` / `govulncheck ./...` / `pip-audit`; `npx license-checker --summary` / `go-licenses check ./...`; verify package-lock.json / go.sum exists
>
> **Test Strategy**
> Sub-dimensions: unit test coverage / integration tests / E2E / CI automation
> Scope: unit/integration/E2E layering, coverage rate, CI automation
> 10-point standard: core business logic unit test coverage ≥ 80%; main API endpoints have integration tests; CI auto-runs all tests on every commit; tests are maintainable (no magic numbers, no duplicate setup)
> Detection: `go test -coverprofile=coverage.out ./... && go tool cover -func=coverage.out | grep total` / `jest --coverage --coverageReporters=text-summary`; check .github/workflows/ or .gitlab-ci.yml for test jobs
>
> **Code Quality**
> Sub-dimensions: cyclomatic complexity / duplication rate / naming conventions / function length
> Scope: readability, naming, duplicate code, function complexity
> 10-point standard: no duplicated logic (DRY); functions have single responsibility, length < 50 lines; no single-letter variable names (except i/j loop vars), no ambiguous names like `data/tmp/result/utils/helper`; cyclomatic complexity < 10; no commented-out dead code
> Detection: `gocyclo -over 10 .` / `eslint --max-warnings 0`; `jscpd --min-tokens 50 .` detect duplicate code; `grep -rn "//.*=" --include="*.go" .` scan for commented-out code
>
> **Architecture Maturity**
> Scope: module decoupling, dependency direction, interface abstraction, extensibility
> 10-point standard: no circular dependencies between modules; dependency direction is unidirectional (higher layers don't depend on lower-layer implementations); interfaces separated from implementations; new features don't require modifying core modules; module boundaries are clear and verifiable
> Detection: `go tool vet ./...`; `madge --circular src/`; `grep -rn "import" --include="*.go" .` verify internal packages aren't cross-layer referenced; `deptrac analyze` (PHP/Java)
>
> **Performance**
> Sub-dimensions: P99 response time / N+1 queries / indexes / memory leaks
> Scope: response time, throughput, database queries, resource usage
> 10-point standard: P99 response < 500ms (or per business SLA); no N+1 queries; hotspot queries have indexes; no memory leaks; large datasets use pagination/streaming
> Detection: `EXPLAIN ANALYZE <slow query>` check execution plan; `k6 run load_test.js` / `artillery run` load test; Go: `go tool pprof`; JS: Chrome DevTools Memory snapshot
>
> **Observability**
> Sub-dimensions: structured logging / metrics / distributed tracing / alert rules
> Scope: logging, metrics, distributed tracing, alerting
> 10-point standard: structured logging (JSON format with level/time/trace_id); key business operations have metrics (request count, error rate, latency); errors have trace IDs for investigation; at least 2 alert rules (① service unavailable ② error rate > 5% for 1 minute)
> Detection: `grep -rn "fmt\.Print\|console\.log\|print(" --include="*.go" --include="*.ts" .` check unstructured logs; verify /metrics endpoint; check Prometheus rules or Grafana alert config files
>
> **Documentation Quality**
> Sub-dimensions: API docs / README / ADR / ops docs
> Scope: API documentation, README, architecture decision records
> 10-point standard: API has OpenAPI/Swagger or equivalent spec; README lets a new developer run locally within 10 minutes; key architectural decisions have ADR records; deployment/ops steps are documented
> Detection: check swagger.yaml / openapi.json / docs/swagger/ exists; execute README Quick Start commands line by line to verify; `ls docs/adr/` check ADR directory
>
> **Developer/User Experience**
> Scope (backend service): API usability, error messages, local dev experience
> Scope (frontend/full-stack): core flow smoothness, error prompts, loading states
> 10-point standard (backend): ① all error responses contain code+message+request_id ② API path/naming style consistent (all RESTful or all RPC, no mixing) ③ single command to start full local environment (e.g., make dev) ④ no 500 errors exposing raw stack traces
> 10-point standard (frontend): key flows have no unnecessary steps; all async operations have loading states; errors have user-friendly messages, not raw stack traces
> Detection: `grep -rn "500\|InternalServerError\|stack\|stacktrace" --include="*.go" --include="*.ts" .`; curl all error endpoints to verify response format
>
> **Compliance & Data Governance**
> Sub-dimensions: PII identification & masking / data retention policy / compliance checklist
> Scope: PII handling, data retention, applicable regulations (GDPR/CCPA/SOC2)
> 10-point standard: PII fields (email/phone/SSN/passport/ID etc.) are identified, masked, or encrypted; no raw PII in logs; data retention/deletion policy is documented and implemented; applicable compliance requirements have item-by-item checklists
> Detection: `grep -rn "email\|phone\|ssn\|passport\|id_card\|credit_card" --include="*.log" .` check logs for PII; `grep -rn "email\|phone" --include="*.go" --include="*.ts" .` confirm fields have masking; check privacy policy/compliance docs
>
> **Operability**
> Sub-dimensions: health checks / runbook / backup & recovery / config management
> Scope: ops documentation, backup & recovery, config management, self-healing
> 10-point standard: has /health and /ready endpoints; has Runbook (common failure handling steps); database/critical data has backup strategy and recovery drill records; config changes don't require redeployment (env vars/config center); infrastructure changes have version control (IaC)
> Detection: `curl -f http://localhost:PORT/health`; `curl -f http://localhost:PORT/ready`; check docs/runbook.md or runbooks/ directory; check backup cron job config; check terraform/ or k8s/ directory

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

1. **Estimate scope**: if the fix involves > 20 files or > 500 lines, split the dimension into sub-tasks (e.g., Security → Input Validation, Secrets Management, Encryption) and handle them one at a time
2. **Run the detection command** for this dimension first to scope the problems (detection commands are listed in each dimension definition above)
3. Analyze the root cause in detail
4. Implement fixes; **commit after each sub-problem**:
   ```bash
   git add -A && git commit -m "vibe-production: [dimension] fix [sub-problem] — brief description"
   ```
5. Self-validate (re-run detection command, confirm issue is resolved)
6. If errors occur, fix them before continuing

### Step 4: Update the Scorecard and Commit

After completing the full dimension:
1. Update `production_scorecard.md`:
   - Update the dimension's score (including sub-scores)
   - Update the remaining issues description
   - Append to history: `- [Date] [Dimension] X→Y — what changed | Next: [next dimension or sub-task]`
2. Final commit:
   ```bash
   git add -A && git commit -m "vibe-production: [dimension] X→Y — brief description"
   ```
   If the project has no git repository yet, run `git init` first.

### Step 5: Check Production Readiness

Verify all of the following are simultaneously satisfied:
- Security = 10 (hard requirement)
- Stability + Dependency Health both ≥ 8
- Compliance & Data Governance ≥ 7
- All other dimensions ≥ 7
- No dimension below 6

**Met** → Output production-readiness report summarizing final scores and key improvements, noting dimensions with remaining room for improvement

**Not met** → Return to Step 2, continue with the lowest-scoring dimension blocking release

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
