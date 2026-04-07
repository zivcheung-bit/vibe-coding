# Vibe Production

A Claude Code custom command that drives your project to production-readiness using a scorecard-driven iteration method.

Type `/vibe-production` in any project and the AI automatically scores, fixes, and loops until all production thresholds are met.

---

## Scoring Dimensions (13 dimensions, optimized for mid-scale production environments)

| Priority | Dimension | Description |
|----------|-----------|-------------|
| 1 | Security | OWASP Top 10, secrets management, encryption (sub-dimensions: auth / input-validation / encryption / OWASP) |
| 2 | Dependency Health | CVE scanning, license compliance, version pinning, CI auto-scan |
| 3 | Compliance & Data Governance | PII identification & masking, data retention policy, GDPR/CCPA/SOC2 checklist |
| 4 | Architecture Maturity | Module decoupling, circular dependency detection, interface abstraction |
| 5 | Feature Completeness | Item-by-item verification against feature checklist, edge case coverage |
| 6 | Stability | Timeouts & retries, graceful shutdown, panic fallback, error context |
| 7 | Test Strategy | Unit test coverage ≥ 80%, integration tests, E2E, CI automation |
| 8 | Code Quality | Cyclomatic complexity < 10, naming conventions, no duplicate logic, functions < 50 lines |
| 9 | Performance | P99 response < 500ms, N+1 queries, indexes, memory leaks |
| 10 | Observability | Structured logging, metrics, trace_id, alert rules |
| 11 | Operability | /health + /ready endpoints, Runbook, backup & recovery, IaC |
| 12 | Documentation Quality | API docs, README, ADR, ops documentation |
| 13 | Developer/User Experience | Backend: DX checklist; Frontend: UX evaluation |

## Production Readiness Thresholds (not all dimensions need to reach 10)

- Security = 10 (hard requirement)
- Stability + Dependency Health both ≥ 8
- Compliance & Data Governance ≥ 7
- All other dimensions ≥ 7, no dimension below 6

---

## Installation

### Option 1: One-liner script (recommended)

```bash
git clone https://github.com/zivcheung-bit/vibe-coding.git
cd vibe-coding
bash install.sh
```

### Option 2: curl single-line install

```bash
mkdir -p ~/.claude/commands && curl -fsSL \
  https://raw.githubusercontent.com/zivcheung-bit/vibe-coding/main/vibe-production.md \
  -o ~/.claude/commands/vibe-production.md
```

### Option 3: Manual

1. Download `vibe-production.md`
2. Place it at `~/.claude/commands/vibe-production.md`

---

## Usage

```
# In any project directory, open Claude Code and type:
/vibe-production
```

**First run**: AI explores code → determines project type → fills feature checklist → creates `production_scorecard.md` (with sub-dimension scores) → starts fixing the first dimension

**Subsequent runs**: reads existing scorecard → continues from last progress

**Production ready**: automatically stops when thresholds are met, outputs production-readiness report with final scores and key improvements

---

## Skip Confirmation Prompts

```bash
claude --dangerously-skip-permissions
```

Start Claude Code, then type `/vibe-production` — no manual confirmations needed throughout.

---

## Files

```
vibe-coding/
├── vibe-production.md  # Claude Code custom command (install to ~/.claude/commands/)
├── install.sh          # One-click install script
└── README.md           # Documentation
```
