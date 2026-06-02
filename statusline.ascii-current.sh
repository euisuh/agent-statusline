#!/bin/bash
# ✨ Fancy Claude Code Status Line
# Install: chmod +x ~/.claude/statusline.sh
# Settings: { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0, "refreshInterval": 60 } }

input=$(cat)

# ── Caveman State ────────────────────────────────────────
CAVEMAN_FLAG="$HOME/.claude/.caveman-active"
CAVEMAN_MODE=""
if [ -f "$CAVEMAN_FLAG" ]; then
  CAVEMAN_MODE=$(tr -d '[:space:]' < "$CAVEMAN_FLAG" 2>/dev/null | tr '[:lower:]' '[:upper:]')
fi

# ── Colors ──────────────────────────────────────────────
RESET="\033[0m"
BOLD=""
DIM="\033[2m"

# Foregrounds
WHITE="\033[97m"
GRAY="\033[90m"
MAGENTA="\033[95m"
# Spectrum (blue→cyan→teal→green→lime→yellow→gold→orange→scarlet→red)
BLUE="\033[38;5;27m"
CYAN="\033[38;5;33m"
SKY="\033[38;5;39m"
TEAL="\033[38;5;44m"
GREEN="\033[38;5;82m"
LIME="\033[38;5;118m"
YELLOW="\033[38;5;226m"
GOLD="\033[38;5;214m"
ORANGE="\033[38;5;208m"
SCARLET="\033[38;5;202m"
RED="\033[38;5;196m"

# ── Extract Fields ───────────────────────────────────────
FIELDS=()
while IFS= read -r field; do FIELDS+=("$field"); done < <(
  jq -r '[
    .model.display_name // "unknown",
    (.context_window.used_percentage // 0 | tostring | split(".")[0]),
    .context_window.context_window_size // 0,
    .cost.total_cost_usd // 0,
    .cost.total_duration_ms // 0,
    .cost.total_lines_added // 0,
    .cost.total_lines_removed // 0,
    .workspace.current_dir // "",
    .workspace.project_dir // "",
    .workspace.git_worktree // "",
    .rate_limits.five_hour.used_percentage // "",
    .rate_limits.five_hour.resets_at // "",
    .rate_limits.seven_day.used_percentage // "",
    .rate_limits.seven_day.resets_at // ""
  ][]' <<< "$input"
)
MODEL="${FIELDS[0]}"
CTX_PCT="${FIELDS[1]}"
CTX_SIZE="${FIELDS[2]}"
COST="${FIELDS[3]}"
DURATION_MS="${FIELDS[4]}"
LINES_ADD="${FIELDS[5]}"
LINES_DEL="${FIELDS[6]}"
CWD="${FIELDS[7]}"
PROJECT_DIR="${FIELDS[8]}"
WORKTREE="${FIELDS[9]}"
RL5H_PCT="${FIELDS[10]}"
RL5H_RESET="${FIELDS[11]}"
RL7D_PCT="${FIELDS[12]}"
RL7D_RESET="${FIELDS[13]}"

# ── Derived Values ───────────────────────────────────────
# Format cost
COST_FMT=$(printf "%.3f" "$COST" 2>/dev/null || echo "0.000")

# Format duration
DURATION_SEC=$(( DURATION_MS / 1000 ))
if [ "$DURATION_SEC" -ge 3600 ]; then
  DURATION_FMT=$(printf "%dh%02dm" "$(( DURATION_SEC / 3600 ))" "$(( (DURATION_SEC % 3600) / 60 ))")
elif [ "$DURATION_SEC" -ge 60 ]; then
  DURATION_FMT=$(printf "%dm%02ds" "$(( DURATION_SEC / 60 ))" "$(( DURATION_SEC % 60 ))")
else
  DURATION_FMT="${DURATION_SEC}s"
fi

# Context window size in k
if [ "$CTX_SIZE" -ge 1000000 ]; then
  CTX_SIZE_FMT="1M"
elif [ "$CTX_SIZE" -ge 1000 ]; then
  CTX_SIZE_FMT="$(( CTX_SIZE / 1000 ))k"
else
  CTX_SIZE_FMT="${CTX_SIZE}"
fi

# Context bar (12 chars wide)
BAR_WIDTH=12
FILLED=$(( (CTX_PCT * BAR_WIDTH + 50) / 100 ))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED="$BAR_WIDTH"
[ "$FILLED" -lt 0 ] && FILLED=0
EMPTY=$(( BAR_WIDTH - FILLED ))
BAR_FILLED=""
BAR_EMPTY=""
if [ "$CTX_PCT" -ge 98 ]; then
  i=0; while [ "$i" -lt $(( BAR_WIDTH - 1 )) ]; do BAR_FILLED+="#"; i=$(( i + 1 )); done
  BAR_FILLED+=">"
else
  i=0; while [ "$i" -lt "$FILLED" ]; do BAR_FILLED+="#"; i=$(( i + 1 )); done
  i=0; while [ "$i" -lt "$EMPTY" ]; do BAR_EMPTY+="-"; i=$(( i + 1 )); done
fi

# Context color based on usage, five stages from plenty left to nearly full
if [ "$CTX_PCT" -lt 25 ]; then
  CTX_COLOR="$CYAN"
elif [ "$CTX_PCT" -lt 50 ]; then
  CTX_COLOR="$GREEN"
elif [ "$CTX_PCT" -lt 70 ]; then
  CTX_COLOR="$YELLOW"
elif [ "$CTX_PCT" -lt 85 ]; then
  CTX_COLOR="$MAGENTA"
else
  CTX_COLOR="$RED"
fi

# Cost color
COST_INT=$(echo "$COST" | cut -d. -f1)
if [ "$COST_INT" -ge 5 ]; then
  COST_COLOR="$RED"
elif [ "$COST_INT" -ge 1 ]; then
  COST_COLOR="$YELLOW"
else
  COST_COLOR="$GREEN"
fi

# ── Git Info ─────────────────────────────────────────────
GIT_DIR="${CWD:-$PROJECT_DIR}"
GIT_BRANCH=""
GIT_STAGED=0
GIT_UNSTAGED=0
GIT_UNTRACKED=0
GIT_AHEAD=0
GIT_BEHIND=0
IS_GIT=false

if [ -n "$GIT_DIR" ] && git -C "$GIT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
  IS_GIT=true
  while IFS= read -r line; do
    if [[ "$line" == "## "* ]]; then
      branch_line="${line#'## '}"
      GIT_BRANCH="${branch_line%%...*}"
      GIT_BRANCH="${GIT_BRANCH%% \[*}"
      GIT_BRANCH="${GIT_BRANCH#No commits yet on }"
      [[ "$GIT_BRANCH" == "HEAD (no branch)" ]] && GIT_BRANCH=$(git -C "$GIT_DIR" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
      if [[ "$branch_line" =~ ahead[[:space:]]([0-9]+) ]]; then GIT_AHEAD="${BASH_REMATCH[1]}"; fi
      if [[ "$branch_line" =~ behind[[:space:]]([0-9]+) ]]; then GIT_BEHIND="${BASH_REMATCH[1]}"; fi
      continue
    fi
    status="${line:0:2}"
    x="${status:0:1}"
    y="${status:1:1}"
    if [ "$status" = "??" ]; then
      GIT_UNTRACKED=$(( GIT_UNTRACKED + 1 ))
    else
      [ "$x" != " " ] && GIT_STAGED=$(( GIT_STAGED + 1 ))
      [ "$y" != " " ] && GIT_UNSTAGED=$(( GIT_UNSTAGED + 1 ))
    fi
  done < <(git -C "$GIT_DIR" --no-optional-locks status --porcelain=v1 --branch 2>/dev/null)
  [ -z "$GIT_BRANCH" ] && GIT_BRANCH=$(git -C "$GIT_DIR" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$GIT_DIR" rev-parse --short HEAD 2>/dev/null)
fi

# ── Model short name ─────────────────────────────────────
# Strip redundant prefixes for cleaner display
MODEL_SHORT=$(echo "$MODEL" | sed 's/Claude //I' | sed 's/claude-//I')

# ── Folder name ──────────────────────────────────────────
FOLDER="${CWD##*/}"
[ -z "$FOLDER" ] && FOLDER="${PROJECT_DIR##*/}"

# ── Line 1: Model · Context · Cost · Time ────────────────
SEP="${GRAY} | ${RESET}"
CTX_PCT_FMT=$(printf "%3d%%" "$CTX_PCT")

LINE1=""
if [ -n "$CAVEMAN_MODE" ]; then
  if [ "$CAVEMAN_MODE" = "FULL" ]; then
    LINE1+="${BOLD}${ORANGE}[CAVEMAN]${RESET}"
  else
    LINE1+="${BOLD}${ORANGE}[CAVEMAN:${CAVEMAN_MODE}]${RESET}"
  fi
  LINE1+="$SEP"
fi
LINE1+="${BOLD}${MAGENTA}${MODEL_SHORT}${RESET}"
LINE1+="$SEP"
LINE1+="${CTX_COLOR}[${BAR_FILLED}${DIM}${BAR_EMPTY}${RESET}${CTX_COLOR}] ${CTX_PCT_FMT}${RESET}${GRAY}/${CTX_SIZE_FMT}${RESET}"
LINE1+="$SEP"
LINE1+="${COST_COLOR}\$${COST_FMT}${RESET}"
LINE1+="$SEP"
LINE1+="${GRAY}${DURATION_FMT}${RESET}"

# Lines changed (only show if non-zero)
if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
  LINE1+="$SEP"
  LINE1+="${GREEN}+${LINES_ADD}${RESET}${GRAY}/${RESET}${RED}-${LINES_DEL}${RESET}"
fi

# ── Line 2: Git ───────────────────────────────────────────
LINE2=""
if $IS_GIT; then
  # Folder + branch
  LINE2+="${BOLD}${BLUE}[/] ${FOLDER}${RESET}"
  LINE2+=" ${GRAY}@${RESET} "

  # Worktree indicator
  if [ -n "$WORKTREE" ]; then
    LINE2+="${CYAN}${GIT_BRANCH}${RESET}${GRAY}[wt:${WORKTREE}]${RESET}"
  else
    LINE2+="${CYAN}${GIT_BRANCH}${RESET}"
  fi

  # Ahead/behind
  if [ "$GIT_AHEAD" -gt 0 ] && [ "$GIT_BEHIND" -gt 0 ]; then
    LINE2+=" ${YELLOW}^${GIT_AHEAD}v${GIT_BEHIND}${RESET}"
  elif [ "$GIT_AHEAD" -gt 0 ]; then
    LINE2+=" ${GREEN}^${GIT_AHEAD}${RESET}"
  elif [ "$GIT_BEHIND" -gt 0 ]; then
    LINE2+=" ${RED}v${GIT_BEHIND}${RESET}"
  fi

  LINE2+="$SEP"

  # Staged / unstaged / untracked — only non-zero
  GIT_PARTS=""
  [ "$GIT_STAGED" -gt 0 ]   && GIT_PARTS+="${GREEN}+${GIT_STAGED}${RESET} "
  [ "$GIT_UNSTAGED" -gt 0 ] && GIT_PARTS+="${YELLOW}~${GIT_UNSTAGED}${RESET} "
  [ "$GIT_UNTRACKED" -gt 0 ]&& GIT_PARTS+="${GRAY}?${GIT_UNTRACKED}${RESET} "

  if [ -n "$GIT_PARTS" ]; then
    LINE2+="$GIT_PARTS"
  else
    LINE2+="${GREEN}.${RESET}"
  fi
else
  # No git — just show folder
  LINE2+="${BOLD}${BLUE}[/] ${FOLDER}${RESET}${GRAY} (no git)${RESET}"
fi

# ── Line 3: Usage / Rate Limits ─────────────────────────
LINE3=""

# Helper: format seconds until reset
fmt_reset() {
  local secs=$(( $1 - $(date +%s) ))
  [ "$secs" -le 0 ] && printf "%6s" "now" && return
  local d=$(( secs / 86400 ))
  local h=$(( (secs % 86400) / 3600 ))
  local m=$(( (secs % 3600) / 60 ))
  if   [ "$d" -gt 0 ]; then printf "%6s" "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then printf "%6s" "${h}h${m}m"
  else printf "%6s" "${m}m"; fi
}

# Helper: rate limit bar (8 chars)
rl_bar() {
  local pct="${1:-0}"
  local pct_int=$(pct_int "$pct")
  local filled=$(( (pct_int * 8 + 50) / 100 ))
  [ "$filled" -gt 8 ] && filled=8
  [ "$filled" -lt 0 ] && filled=0
  local empty=$(( 8 - filled ))
  local bar=""
  local i=0
  if [ "$pct_int" -ge 98 ]; then
    while [ "$i" -lt 7 ]; do bar+="#"; i=$(( i + 1 )); done
    bar+=">"
  else
    while [ "$i" -lt "$filled" ]; do bar+="#"; i=$(( i + 1 )); done
    [ "$empty" -gt 0 ] && bar+="${DIM}"
    i=0
    while [ "$i" -lt "$empty" ]; do bar+="-"; i=$(( i + 1 )); done
  fi
  echo "$bar"
}

# Helper: color for rate limit (simple threshold fallback)
rl_color() {
  local pct_int=$(pct_int "$1")
  if   [ "$pct_int" -ge 98 ]; then echo "$RED"
  elif [ "$pct_int" -ge 90 ]; then echo "$SCARLET"
  elif [ "$pct_int" -ge 80 ]; then echo "$ORANGE"
  elif [ "$pct_int" -ge 70 ]; then echo "$GOLD"
  elif [ "$pct_int" -ge 60 ]; then echo "$YELLOW"
  elif [ "$pct_int" -ge 50 ]; then echo "$LIME"
  elif [ "$pct_int" -ge 40 ]; then echo "$GREEN"
  elif [ "$pct_int" -ge 30 ]; then echo "$TEAL"
  elif [ "$pct_int" -ge 20 ]; then echo "$SKY"
  elif [ "$pct_int" -ge 10 ]; then echo "$CYAN"
  else echo "$BLUE"; fi
}

# Helper: time-paced color — cool=under, yellow=on/near, warm=over schedule
# Args: usage_pct reset_at_epoch window_secs
rl_color_timed() {
  local usage_int=$(pct_int "$1")
  local reset_at="${2:-0}"
  local window="${3:-18000}"
  if [ -n "$reset_at" ] && [ "$reset_at" -gt 0 ] 2>/dev/null; then
    local now=$(date +%s)
    local elapsed=$(( window - (reset_at - now) ))
    [ "$elapsed" -lt 0 ] && elapsed=0
    local time_pct=$(( elapsed * 100 / window ))
    local delta=$(( usage_int - time_pct ))
    if   [ "$delta" -gt 40 ]; then echo "$RED"
    elif [ "$delta" -gt 30 ]; then echo "$SCARLET"
    elif [ "$delta" -gt 22 ]; then echo "$ORANGE"
    elif [ "$delta" -gt 15 ]; then echo "$GOLD"
    elif [ "$delta" -gt 8 ]; then echo "$YELLOW"
    elif [ "$delta" -gt 2 ]; then echo "$LIME"
    elif [ "$delta" -gt -4 ]; then echo "$GREEN"
    elif [ "$delta" -gt -10 ]; then echo "$TEAL"
    elif [ "$delta" -gt -18 ]; then echo "$SKY"
    elif [ "$delta" -gt -28 ]; then echo "$CYAN"
    else echo "$BLUE"; fi
  else
    rl_color "$1"
  fi
}

# ── Helper: safe integer pct + fixed 3-char format ───────
pct_int() {
  local v="${1:-0}"
  v="${v%%.*}"
  [[ "$v" =~ ^-?[0-9]+$ ]] || v=0
  echo "$v"
}

fmt_pct() {
  local v
  v=$(pct_int "$1")
  [ "$v" -gt 999 ] && v=999
  [ "$v" -lt 0 ] && v=0
  printf "%3d%%" "$v"
}

# ── Helper: fmt seconds (not epoch) ──────────────────────
fmt_secs() {
  local s="$1"
  local d=$(( s / 86400 ))
  local h=$(( (s % 86400) / 3600 ))
  local m=$(( (s % 3600) / 60 ))
  if   [ "$d" -gt 0 ]; then printf "%-6s" "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then printf "%-6s" "${h}h${m}m"
  else printf "%-6s" "${m}m"; fi
}

# ── 5-hour rate limit ─────────────────────────────────────
if [ -n "$RL5H_PCT" ]; then
  RL5H_INT=$(echo "$RL5H_PCT" | cut -d. -f1)
  RL5H_COLOR=$(rl_color_timed "$RL5H_PCT" "$RL5H_RESET" 18000)
  RL5H_BAR=$(rl_bar "$RL5H_PCT")
  RL5H_RESET_FMT=""
  [ -n "$RL5H_RESET" ] && RL5H_RESET_FMT=" ${GRAY}->${RESET} ${CYAN}$(fmt_reset "$RL5H_RESET")${RESET}"
  LINE3+="${GRAY}5h ${RESET}${RL5H_COLOR}[${RL5H_BAR}${RESET}${RL5H_COLOR}] $(fmt_pct $RL5H_INT)${RESET}${RL5H_RESET_FMT}"
fi

# ── 7-day rate limit ──────────────────────────────────────
if [ -n "$RL7D_PCT" ]; then
  RL7D_INT=$(echo "$RL7D_PCT" | cut -d. -f1)
  RL7D_COLOR=$(rl_color_timed "$RL7D_PCT" "$RL7D_RESET" 604800)
  RL7D_BAR=$(rl_bar "$RL7D_PCT")
  RL7D_RESET_FMT=""
  [ -n "$RL7D_RESET" ] && RL7D_RESET_FMT=" ${GRAY}->${RESET} ${CYAN}$(fmt_reset "$RL7D_RESET")${RESET}"
  [ -n "$LINE3" ] && LINE3+="$SEP"
  LINE3+="${GRAY}7d ${RESET}${RL7D_COLOR}[${RL7D_BAR}${RESET}${RL7D_COLOR}] $(fmt_pct $RL7D_INT)${RESET}${RL7D_RESET_FMT}"
fi

if [ -z "$LINE3" ]; then
  LINE3+="${GRAY}5h ${RESET}${GRAY}[--------] ---%${RESET} ${GRAY}->${RESET} ${CYAN}    --${RESET}"
  LINE3+="$SEP"
  LINE3+="${GRAY}7d ${RESET}${GRAY}[--------] ---%${RESET} ${GRAY}->${RESET} ${CYAN}    --${RESET}"
fi

# ── Monthly spend from ~/.claude/usage.jsonl ─────────────
USAGE_FILE="$HOME/.claude/usage.jsonl"
if [ -f "$USAGE_FILE" ]; then
  THIS_MONTH=$(date +%Y-%m)
  CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agent-statusline"
  MONTHLY_CACHE="$CACHE_DIR/monthly-spend"
  NOW_EPOCH=$(date +%s)
  CACHE_TS=0
  CACHE_MONTH=""
  CACHE_COST=""
  mkdir -p "$CACHE_DIR" 2>/dev/null
  [ -r "$MONTHLY_CACHE" ] && IFS='|' read -r CACHE_TS CACHE_MONTH CACHE_COST < "$MONTHLY_CACHE"
  if [[ "$CACHE_TS" =~ ^[0-9]+$ ]] && [ "$CACHE_MONTH" = "$THIS_MONTH" ] && [ $(( NOW_EPOCH - CACHE_TS )) -lt 60 ]; then
    MONTHLY_COST="$CACHE_COST"
  else
    MONTHLY_COST=$(grep -h "." "$USAGE_FILE" 2>/dev/null \
      | jq -r --arg m "$THIS_MONTH" \
        'select((.timestamp? // "") | startswith($m)) | .costUSD // .cost_usd // 0' \
      | awk '{s+=$1} END {printf "%.3f", s+0}' 2>/dev/null || echo "")
    [ -n "$MONTHLY_COST" ] && printf "%s|%s|%s\n" "$NOW_EPOCH" "$THIS_MONTH" "$MONTHLY_COST" > "$MONTHLY_CACHE.tmp" 2>/dev/null && mv "$MONTHLY_CACHE.tmp" "$MONTHLY_CACHE" 2>/dev/null
  fi
  if [ -n "$MONTHLY_COST" ] && [ "$MONTHLY_COST" != "0.000" ]; then
    MONTHLY_INT=$(echo "$MONTHLY_COST" | cut -d. -f1)
    if   [ "$MONTHLY_INT" -ge 50 ]; then MONTHLY_COLOR="$RED"
    elif [ "$MONTHLY_INT" -ge 20 ]; then MONTHLY_COLOR="$YELLOW"
    else MONTHLY_COLOR="$GREEN"; fi
    [ -n "$LINE3" ] && LINE3+="$SEP"
    LINE3+="${GRAY}$(date +%b) ${RESET}${MONTHLY_COLOR}\$${MONTHLY_COST}${RESET}"
  fi
fi

[ -n "$LINE3" ] && LINE3="${ORANGE}(C)${RESET} ${LINE3}"

# ── Line 4: Codex Quota ───────────────────────────────────
LINE4=""
CODEX_QUOTA=$(python3 "$HOME/.claude/codex_quota.py" 2>/dev/null)
if [ -n "$CODEX_QUOTA" ]; then
  IFS=$'\t' read -r CX_PRI CX_PRI_AT CX_PRI_RST CX_SEC CX_SEC_AT CX_SEC_RST CX_LIM < <(
    jq -r '
      def fmt_secs:
        . as $s
        | ($s / 86400 | floor) as $d
        | (($s % 86400) / 3600 | floor) as $h
        | (($s % 3600) / 60 | floor) as $m
        | if $d > 0 then "\($d)d\($h)h"
          elif $h > 0 then "\($h)h\($m)m"
          else "\($m)m"
          end;
      select(has("primary_pct")) |
      [
        .primary_pct,
        .primary_reset_at,
        (.primary_reset_secs // 0 | fmt_secs),
        .secondary_pct,
        .secondary_reset_at,
        (.secondary_reset_secs // 0 | fmt_secs),
        .limit_reached
      ] | @tsv' <<< "$CODEX_QUOTA" 2>/dev/null
  )
fi
if [ -n "$CX_PRI" ]; then
  CX_PRI_RST=$(printf "%6s" "$CX_PRI_RST")
  CX_SEC_RST=$(printf "%6s" "$CX_SEC_RST")

  if [ "$CX_LIM" = "True" ] || [ "$CX_LIM" = "true" ]; then
    [ "$(pct_int "$CX_PRI")" -lt 100 ] && CX_PRI=100
    [ "$(pct_int "$CX_SEC")" -lt 100 ] && CX_SEC=100
  fi

  # Time-paced color — same logic as Claude
  CX_PRI_COLOR=$(rl_color_timed "$CX_PRI" "$CX_PRI_AT" 18000)
  CX_PRI_BAR=$(rl_bar "$CX_PRI")
  CX_SEC_COLOR=$(rl_color_timed "$CX_SEC" "$CX_SEC_AT" 604800)
  CX_SEC_BAR=$(rl_bar "$CX_SEC")

  LINE4="${TEAL}</>${RESET} ${GRAY}5h ${RESET}${CX_PRI_COLOR}[${CX_PRI_BAR}${RESET}${CX_PRI_COLOR}] $(fmt_pct $CX_PRI)${RESET} ${GRAY}->${RESET} ${CYAN}${CX_PRI_RST}${RESET}"
  LINE4+="$SEP"
  LINE4+="${GRAY}7d ${RESET}${CX_SEC_COLOR}[${CX_SEC_BAR}${RESET}${CX_SEC_COLOR}] $(fmt_pct $CX_SEC)${RESET} ${GRAY}->${RESET} ${CYAN}${CX_SEC_RST}${RESET}"
fi

# ── Output ────────────────────────────────────────────────
if [ -n "$LINE3" ] && [ -n "$LINE4" ]; then
  printf "%b\n%b\n%b\n%b\n" "$LINE1" "$LINE2" "$LINE3" "$LINE4"
elif [ -n "$LINE3" ]; then
  printf "%b\n%b\n%b\n" "$LINE1" "$LINE2" "$LINE3"
elif [ -n "$LINE4" ]; then
  printf "%b\n%b\n%b\n" "$LINE1" "$LINE2" "$LINE4"
else
  printf "%b\n%b\n" "$LINE1" "$LINE2"
fi
