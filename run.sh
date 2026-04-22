#!/bin/bash
# run.sh — Fully-automated driver for vibe-production quality iterations
# bash 3.2+ compatible (works on stock macOS bash)
#
# Usage:
#   vibe-coding/run.sh [options]
#
# Options:
#   -p <path>     Target project directory (default: current directory)
#   -a <agents>   Comma-separated agent list, e.g. "claude,codex" (default: claude)
#   -c            Continue mode: resume from existing scorecard state
#   -n <N>        Max iterations (default: 20)
#   --no-pr       Skip auto PR creation even when all thresholds are met
#
# Environment overrides:
#   PASSING_SCORE   Minimum reviewer score treated as passing (default: threshold)

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
AGENTS_DIR="$SCRIPT_DIR/agents"
VIBE_PROMPT_FILE="$SCRIPT_DIR/vibe-production.md"

# shellcheck source=lib/scorecard_utils.sh
source "$LIB_DIR/scorecard_utils.sh"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
PROJECT_PATH="$(pwd)"
AGENT_LIST="claude"
CONTINUE_MODE=false
MAX_ITER=20
CREATE_PR=true

SCORECARD_FILE=""   # resolved after args parsed
STATUS_FILE=""

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log()  { printf '[vibe] %s\n' "$*"; }
info() { printf '[vibe] ℹ  %s\n' "$*"; }
ok()   { printf '[vibe] ✅ %s\n' "$*"; }
warn() { printf '[vibe] ⚠  %s\n' "$*" >&2; }
err()  { printf '[vibe] ❌ %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -p <path>   Target project directory (default: current directory)
  -a <agents> Agent list: claude | codex | opencode | comma-separated (default: claude)
  -c          Continue from existing scorecard without re-initialising
  -n <N>      Max iterations (default: 20)
  --no-pr     Do not create a GitHub PR when finished
  -h          Show this help

Examples:
  # Run in current directory using Claude only
  $(basename "$0")

  # Run on a specific project, Claude implements + Codex reviews
  $(basename "$0") -p ~/my-project -a claude,codex

  # Resume a previous run
  $(basename "$0") -p ~/my-project -c

  # Cap at 10 iterations, skip auto PR
  $(basename "$0") -p ~/my-project -n 10 --no-pr
EOF
  exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -p)      PROJECT_PATH="$2"; shift 2 ;;
      -a)      AGENT_LIST="$2";   shift 2 ;;
      -c)      CONTINUE_MODE=true; shift  ;;
      -n)      MAX_ITER="$2";     shift 2 ;;
      --no-pr) CREATE_PR=false;   shift   ;;
      -h|--help) usage ;;
      *) err "Unknown option: $1"; usage ;;
    esac
  done

  PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
  SCORECARD_FILE="$PROJECT_PATH/production_scorecard.md"
  STATUS_FILE="$PROJECT_PATH/production_status.json"

  init_scorecard_utils "$PROJECT_PATH"
}

# ---------------------------------------------------------------------------
# Agent list (no associative arrays — indexed arrays only for bash 3.2)
# ---------------------------------------------------------------------------
AGENT_NAMES=()

parse_agent_list() {
  local IFS=','
  read -ra AGENT_NAMES <<< "$AGENT_LIST"
  local agent
  for agent in "${AGENT_NAMES[@]}"; do
    case "$agent" in
      claude|codex|opencode) ;;
      *) err "Unknown agent: $agent (supported: claude, codex, opencode)"; exit 1 ;;
    esac
  done
}

implementer_agent() {
  echo "${AGENT_NAMES[0]}"
}

# Returns the reviewer agent name for the given iteration, or "" if single-agent.
reviewer_agent() {
  local iter="$1"
  local n="${#AGENT_NAMES[@]}"
  [ "$n" -le 1 ] && { echo ""; return; }
  # Round-robin across agents[1..n-1]
  local idx=$(( 1 + (iter % (n - 1)) ))
  echo "${AGENT_NAMES[$idx]}"
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
check_dependencies() {
  local missing=() agent
  for agent in "${AGENT_NAMES[@]}"; do
    case "$agent" in
      claude)   command -v claude   &>/dev/null || missing+=("claude")   ;;
      codex)    command -v codex    &>/dev/null || missing+=("codex")    ;;
      opencode) command -v opencode &>/dev/null || missing+=("opencode") ;;
    esac
  done

  if [ ${#missing[@]} -gt 0 ]; then
    err "Missing required tools: ${missing[*]}"
    err "Install them and re-run."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Read agent instructions (project override takes precedence)
# ---------------------------------------------------------------------------
get_agent_instructions() {
  local agent="$1"
  local project_override="$PROJECT_PATH/.vibe-production/agents/${agent}.md"
  local default_file="$AGENTS_DIR/${agent}.md"

  if [ -f "$project_override" ]; then
    cat "$project_override"
  elif [ -f "$default_file" ]; then
    cat "$default_file"
  else
    echo "You are a skilled software engineer. Follow the task instructions carefully."
  fi
}

# ---------------------------------------------------------------------------
# Build implementer prompt
# ---------------------------------------------------------------------------
build_implementer_prompt() {
  local dimension="$1"
  local iter="$2"
  local threshold
  threshold=$(get_threshold "$dimension")
  local current_score
  current_score=$(get_dimension_score "$SCORECARD_FILE" "$dimension" 2>/dev/null || echo "unknown")

  local scorecard_content=""
  [ -f "$SCORECARD_FILE" ] && scorecard_content="$(cat "$SCORECARD_FILE")"

  local vibe_prompt agent_instructions
  vibe_prompt="$(cat "$VIBE_PROMPT_FILE")"
  agent_instructions="$(get_agent_instructions "claude")"

  printf '%s\n\n---\n\n## Session Context\n\n**Project directory**: %s\n**Current iteration**: %s\n**Focus dimension**: %s\n**Current score**: %s/10\n**Required threshold**: %s/10\n\n%s\n\n## Agent Instructions\n\n%s\n\n---\n\nWork inside the project directory above. Focus on the **%s** dimension this session.\nDo not ask for confirmation — execute directly.\n' \
    "$vibe_prompt" \
    "$PROJECT_PATH" \
    "$iter" \
    "$dimension" \
    "$current_score" \
    "$threshold" \
    "${scorecard_content:+## Current Scorecard

${scorecard_content}
}" \
    "$agent_instructions" \
    "$dimension"
}

# ---------------------------------------------------------------------------
# Build reviewer prompt
# ---------------------------------------------------------------------------
build_reviewer_prompt() {
  local agent="$1"
  local dimension="$2"
  local iter="$3"
  local threshold
  threshold=$(get_threshold "$dimension")

  local scorecard_content=""
  [ -f "$SCORECARD_FILE" ] && scorecard_content="$(cat "$SCORECARD_FILE")"

  local agent_instructions
  agent_instructions="$(get_agent_instructions "$agent")"

  printf '%s\n\n---\n\n## Review Task\n\n**Project directory**: %s\n**Iteration**: %s\n**Dimension to verify**: %s\n**Required score to pass**: %s/10\n\n## Current Scorecard (written by implementer)\n\n%s\n\n## Instructions\n\nYou are an independent reviewer. Do NOT modify any source code or the scorecard.\n\n1. Inspect the project at **%s** and independently assess the **%s** dimension.\n2. Run the relevant detection commands.\n3. Output your independent score as: **Score: X/10**\n4. State clearly: **PASS** (score >= %s) or **FAIL** (score < %s).\n5. If FAIL, list specific issues that still need fixing.\n\nBe strict and objective. Your review determines whether this iteration moves on.\n' \
    "$agent_instructions" \
    "$PROJECT_PATH" \
    "$iter" \
    "$dimension" \
    "$threshold" \
    "$scorecard_content" \
    "$PROJECT_PATH" \
    "$dimension" \
    "$threshold" \
    "$threshold"
}

# ---------------------------------------------------------------------------
# Run an agent with exponential-backoff retries
# ---------------------------------------------------------------------------
run_agent() {
  local agent="$1"
  local prompt="$2"
  local max_retries=3
  local attempt=0
  local delay=5
  local output=""

  while [ "$attempt" -lt "$max_retries" ]; do
    attempt=$(( attempt + 1 ))
    log "Calling $agent (attempt $attempt/$max_retries)..."

    case "$agent" in
      claude)
        output=$(cd "$PROJECT_PATH" && claude -p "$prompt" --dangerously-skip-permissions 2>&1) \
          && { printf '%s' "$output"; return 0; }
        ;;
      codex)
        output=$(cd "$PROJECT_PATH" && codex exec --full-auto "$prompt" 2>&1) \
          && { printf '%s' "$output"; return 0; }
        ;;
      opencode)
        output=$(cd "$PROJECT_PATH" && opencode run "$prompt" 2>&1) \
          && { printf '%s' "$output"; return 0; }
        ;;
    esac

    warn "$agent exited non-zero (attempt $attempt). Retrying in ${delay}s..."
    sleep "$delay"
    delay=$(( delay * 2 ))
  done

  printf '%s' "$output"
  return 1
}

# ---------------------------------------------------------------------------
# Check whether a reviewer's output indicates the dimension passed
# ---------------------------------------------------------------------------
reviewer_passed() {
  local review_output="$1"
  local dimension="$2"
  local threshold
  threshold=$(get_threshold "$dimension")

  local review_score
  review_score=$(extract_review_score "$review_output")

  # Must explicitly say PASS and score must meet threshold
  if printf '%s' "$review_output" | grep -qi '\bPASS\b'; then
    if [ "$review_score" -ge "$threshold" ] 2>/dev/null; then
      return 0
    fi
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Auto-create GitHub PR
# ---------------------------------------------------------------------------
create_pr() {
  if ! command -v gh &>/dev/null; then
    warn "gh CLI not found — skipping PR creation."
    return 0
  fi

  local branch
  branch=$(cd "$PROJECT_PATH" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ -z "$branch" ] || [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    warn "On default branch or no git repo — skipping PR creation."
    return 0
  fi

  info "Creating GitHub PR..."
  local pr_body
  pr_body=$(printf '## Production Readiness Report\n\nAll vibe-production thresholds have been met.\n\n%s\n\n---\n*Generated by vibe-coding/run.sh*\n' \
    "$(cat "$SCORECARD_FILE" 2>/dev/null || echo '')")

  cd "$PROJECT_PATH"
  gh pr create \
    --title "vibe-production: all thresholds met" \
    --body "$pr_body" 2>/dev/null \
  || warn "PR creation failed (branch may already have an open PR)."
}

# ---------------------------------------------------------------------------
# Print a score summary table
# ---------------------------------------------------------------------------
print_score_summary() {
  [ -f "$SCORECARD_FILE" ] || { info "No scorecard yet."; return; }

  echo ""
  printf "%-37s  %5s  %9s  %s\n" "Dimension" "Score" "Threshold" "Status"
  printf '%0.s─' {1..60}; echo ""

  local dim score threshold status
  for dim in "${DIMENSION_PRIORITY[@]}"; do
    threshold=$(get_threshold "$dim")
    score=$(get_dimension_score "$SCORECARD_FILE" "$dim" 2>/dev/null || echo "?")
    status="⏳"
    if [ "$score" != "?" ]; then
      [ "$score" -ge "$threshold" ] 2>/dev/null && status="✅" || status="❌"
    fi
    printf "%-37s  %5s  %9s  %s\n" "$dim" "$score" "$threshold" "$status"
  done
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  parse_args "$@"
  parse_agent_list
  check_dependencies

  log "Project : $PROJECT_PATH"
  log "Agents  : ${AGENT_NAMES[*]}"
  log "Max iter: $MAX_ITER"
  log "Continue: $CONTINUE_MODE"
  echo ""

  if $CONTINUE_MODE && [ ! -f "$SCORECARD_FILE" ]; then
    warn "Continue mode requested but no scorecard found — starting fresh."
    CONTINUE_MODE=false
  fi

  # Restore iteration counter from status file if continuing
  local iter=0
  if $CONTINUE_MODE && [ -f "$STATUS_FILE" ] && command -v jq &>/dev/null; then
    iter=$(jq -r '.lastIteration // 0' "$STATUS_FILE" 2>/dev/null || echo 0)
    info "Resuming from iteration $iter"
  fi

  # Main iteration loop
  while [ "$iter" -lt "$MAX_ITER" ]; do
    iter=$(( iter + 1 ))
    log "─── Iteration $iter / $MAX_ITER ────────────────────────────────"

    if all_thresholds_met "$SCORECARD_FILE" 2>/dev/null; then
      ok "All thresholds met! 🎉"
      break
    fi

    local next_dim
    next_dim=$(get_next_dimension "$SCORECARD_FILE")
    if [ -z "$next_dim" ]; then
      ok "All dimensions passed."
      break
    fi

    info "Working on: ${next_dim}"

    # --- Implementer ---
    local impl_agent
    impl_agent=$(implementer_agent)
    log "Implementer: $impl_agent"

    local impl_prompt
    impl_prompt=$(build_implementer_prompt "$next_dim" "$iter")
    run_agent "$impl_agent" "$impl_prompt" > /dev/null || warn "$impl_agent exited with errors."

    # --- Reviewer (only in multi-agent mode) ---
    local review_agent
    review_agent=$(reviewer_agent "$iter")

    if [ -n "$review_agent" ]; then
      log "Reviewer: $review_agent"
      local review_prompt review_output
      review_prompt=$(build_reviewer_prompt "$review_agent" "$next_dim" "$iter")
      review_output=$(run_agent "$review_agent" "$review_prompt" || echo "")

      echo ""
      log "Review output (${review_agent}) — last 20 lines:"
      printf '%s\n' "$review_output" | tail -20
      echo ""

      if ! reviewer_passed "$review_output" "$next_dim"; then
        local rev_score
        rev_score=$(extract_review_score "$review_output")
        warn "Reviewer scored ${next_dim} at ${rev_score}/10 — needs more work."
        write_status_json "$STATUS_FILE" "$iter" "$next_dim" "$SCORECARD_FILE" 2>/dev/null || true
        continue
      fi

      ok "Reviewer confirms ${next_dim} passed."
    fi

    write_status_json "$STATUS_FILE" "$iter" "$next_dim" "$SCORECARD_FILE" 2>/dev/null || true
    print_score_summary
  done

  # Final status
  echo ""
  print_score_summary

  if all_thresholds_met "$SCORECARD_FILE" 2>/dev/null; then
    ok "Project is production-ready! 🚀"
    if $CREATE_PR; then
      create_pr
    fi
  else
    warn "Max iterations ($MAX_ITER) reached — some dimensions still below threshold."
    warn "Resume with: $(basename "$0") -p $PROJECT_PATH -c"
    exit 1
  fi
}

main "$@"
