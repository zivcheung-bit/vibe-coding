#!/bin/bash
# scorecard_utils.sh — helpers for production_scorecard.md (bash 3.2+ compatible)

# Dimensions in priority order (used by get_next_dimension)
DIMENSION_PRIORITY=(
  "Security"
  "Dependency Health"
  "Compliance & Data Governance"
  "Architecture Maturity"
  "Feature Completeness"
  "Stability"
  "Test Strategy"
  "Code Quality"
  "Performance"
  "Observability"
  "Operability"
  "Documentation Quality"
  "Developer/User Experience"
)

# Internal: path to optional project-level thresholds.json
_VIBE_THRESHOLDS_FILE=""

# init_scorecard_utils <project_root>
#   Call once after PROJECT_PATH is set.
init_scorecard_utils() {
  _VIBE_THRESHOLDS_FILE="$1/.vibe-production/thresholds.json"
}

# ---------------------------------------------------------------------------
# get_threshold <dimension>
#   Returns the required score for <dimension>.
#   Checks _VIBE_THRESHOLDS_FILE first (project override), then hardcoded defaults.
# ---------------------------------------------------------------------------
get_threshold() {
  local dim="$1"

  # Project-level override (requires jq)
  if [ -f "$_VIBE_THRESHOLDS_FILE" ] && command -v jq &>/dev/null; then
    local custom
    custom=$(jq -r --arg d "$dim" '.[$d] // .default // empty' "$_VIBE_THRESHOLDS_FILE" 2>/dev/null)
    [ -n "$custom" ] && { echo "$custom"; return; }
  fi

  # Hardcoded defaults
  case "$dim" in
    "Security")                        echo 10 ;;
    "Stability")                       echo 8  ;;
    "Dependency Health")               echo 8  ;;
    "Compliance & Data Governance")    echo 7  ;;
    "Feature Completeness")            echo 7  ;;
    "Architecture Maturity")           echo 7  ;;
    "Test Strategy")                   echo 7  ;;
    "Code Quality")                    echo 7  ;;
    "Performance")                     echo 7  ;;
    "Observability")                   echo 7  ;;
    "Operability")                     echo 7  ;;
    "Documentation Quality")           echo 7  ;;
    "Developer/User Experience")       echo 7  ;;
    *)                                 echo 7  ;;
  esac
}

# ---------------------------------------------------------------------------
# parse_scorecard_scores <scorecard_file>
#   Reads the markdown scorecard table and prints "DimensionName=Score" lines
#   for each row whose Score column is a plain integer.
# ---------------------------------------------------------------------------
parse_scorecard_scores() {
  local scorecard_file="$1"
  [ -f "$scorecard_file" ] || return 1

  awk -F'|' '
    $3 ~ /^[[:space:]]*[0-9]+[[:space:]]*$/ {
      dim   = $2
      score = $3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", dim)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", score)
      if (length(dim) > 0 && score + 0 >= 0)
        print dim "=" score
    }
  ' "$scorecard_file"
}

# ---------------------------------------------------------------------------
# get_dimension_score <scorecard_file> <dimension>
#   Prints the score for <dimension>, or empty string if not found.
# ---------------------------------------------------------------------------
get_dimension_score() {
  local scorecard_file="$1"
  local dimension="$2"

  parse_scorecard_scores "$scorecard_file" | \
    awk -F'=' -v dim="$dimension" '$1 == dim { print $2; exit }'
}

# ---------------------------------------------------------------------------
# all_thresholds_met <scorecard_file>
#   Returns 0 if every known dimension meets its threshold and none is below 6.
# ---------------------------------------------------------------------------
all_thresholds_met() {
  local scorecard_file="$1"
  [ -f "$scorecard_file" ] || return 1

  local dim score threshold
  for dim in "${DIMENSION_PRIORITY[@]}"; do
    score=$(get_dimension_score "$scorecard_file" "$dim")
    score="${score:-0}"
    threshold=$(get_threshold "$dim")

    # Must reach dimension threshold
    if [ "$score" -lt "$threshold" ] 2>/dev/null; then
      return 1
    fi
    # Hard floor: no dimension may fall below 6
    if [ "$score" -lt 6 ] 2>/dev/null; then
      return 1
    fi
  done

  return 0
}

# ---------------------------------------------------------------------------
# get_next_dimension <scorecard_file>
#   Prints the highest-priority dimension that has NOT yet reached its threshold.
#   Prints nothing when all dimensions are done.
# ---------------------------------------------------------------------------
get_next_dimension() {
  local scorecard_file="$1"
  local dim score threshold

  for dim in "${DIMENSION_PRIORITY[@]}"; do
    threshold=$(get_threshold "$dim")
    score=$(get_dimension_score "$scorecard_file" "$dim" 2>/dev/null)
    score="${score:-0}"

    if [ "$score" -lt "$threshold" ] 2>/dev/null; then
      echo "$dim"
      return 0
    fi
  done

  echo ""
}

# ---------------------------------------------------------------------------
# extract_review_score <text>
#   Parses a 0-10 score from free-form reviewer output.
#   Tries several patterns; falls back to 0.
# ---------------------------------------------------------------------------
extract_review_score() {
  local text="$1"
  local score=""

  # Pattern: X/10
  score=$(printf '%s' "$text" | grep -oE '([0-9]|10)/10' | tail -1 | cut -d/ -f1)
  [ -n "$score" ] && { echo "$score"; return; }

  # Pattern: Score: X  or  score: X
  score=$(printf '%s' "$text" | grep -iE 'score[[:space:]]*:[[:space:]]*[0-9]+' | \
          grep -oE '[0-9]+$' | tail -1)
  [ -n "$score" ] && { echo "$score"; return; }

  # Pattern: 评分: X  or  评分：X
  score=$(printf '%s' "$text" | grep -oE '评分[：:][[:space:]]*[0-9]+' | \
          grep -oE '[0-9]+$' | tail -1)
  [ -n "$score" ] && { echo "$score"; return; }

  echo "0"
}

# ---------------------------------------------------------------------------
# write_status_json <status_file> <iteration> <current_dim> <scorecard_file>
#   Writes machine-readable JSON status.  Falls back to minimal JSON if jq absent.
# ---------------------------------------------------------------------------
write_status_json() {
  local status_file="$1"
  local iteration="$2"
  local current_dim="$3"
  local scorecard_file="$4"
  local timestamp
  timestamp=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

  if command -v jq &>/dev/null && [ -f "$scorecard_file" ]; then
    # Build dimension objects via awk + jq
    local dims_json
    dims_json=$(parse_scorecard_scores "$scorecard_file" | awk -F'=' '{
      print $1 "\t" $2
    }' | while IFS=$'\t' read -r dim score; do
      threshold=$(get_threshold "$dim")
      passed="false"
      [ "$score" -ge "$threshold" ] 2>/dev/null && passed="true"
      printf '"%s":{"score":%s,"threshold":%s,"passed":%s}\n' \
        "$dim" "$score" "$threshold" "$passed"
    done | paste -sd ',' | sed 's/^/{/;s/$/}/')

    jq -n \
      --argjson iter "$iteration" \
      --arg dim "$current_dim" \
      --argjson dims "${dims_json:-{\}}" \
      --arg ts "$timestamp" \
      '{"lastIteration":$iter,"currentDimension":$dim,"dimensions":$dims,"lastUpdated":$ts}' \
      > "$status_file" 2>/dev/null || true
  else
    printf '{"lastIteration":%d,"currentDimension":"%s","lastUpdated":"%s"}\n' \
      "$iteration" "$current_dim" "$timestamp" > "$status_file"
  fi
}
