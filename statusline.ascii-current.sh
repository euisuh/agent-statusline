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
CYAN="\033[96m"
GREEN="\033[92m"
YELLOW="\033[93m"
RED="\033[91m"
MAGENTA="\033[95m"
BLUE="\033[94m"
GRAY="\033[90m"
ORANGE="\033[38;5;208m"
TEAL="\033[38;5;36m"

# ── Extract Fields ───────────────────────────────────────
MODEL=$(echo "$input"        | jq -r '.model.display_name // "unknown"')
CTX_PCT=$(echo "$input"      | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input"     | jq -r '.context_window.context_window_size // 0')
COST=$(echo "$input"         | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input"  | jq -r '.cost.total_duration_ms // 0')
LINES_ADD=$(echo "$input"    | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input"    | jq -r '.cost.total_lines_removed // 0')
CWD=$(echo "$input"          | jq -r '.workspace.current_dir // ""')
PROJECT_DIR=$(echo "$input"  | jq -r '.workspace.project_dir // ""')
WORKTREE=$(echo "$input"     | jq -r '.workspace.git_worktree // ""')
RL5H_PCT=$(echo "$input"     | jq -r '.rate_limits.five_hour.used_percentage // empty')
RL5H_RESET=$(echo "$input"   | jq -r '.rate_limits.five_hour.resets_at // empty')
RL7D_PCT=$(echo "$input"     | jq -r '.rate_limits.seven_day.used_percentage // empty')
RL7D_RESET=$(echo "$input"   | jq -r '.rate_limits.seven_day.resets_at // empty')

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
i=0
while [ "$i" -lt "$FILLED" ]; do BAR_FILLED+="#"; i=$(( i + 1 )); done
i=0
while [ "$i" -lt "$EMPTY" ]; do BAR_EMPTY+="-"; i=$(( i + 1 )); done

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
  GIT_BRANCH=$(git -C "$GIT_DIR" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$GIT_DIR" rev-parse --short HEAD 2>/dev/null)
  GIT_STAGED=$(git -C "$GIT_DIR" --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  GIT_UNSTAGED=$(git -C "$GIT_DIR" --no-optional-locks diff --numstat 2>/dev/null | wc -l | tr -d ' ')
  GIT_UNTRACKED=$(git -C "$GIT_DIR" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  UPSTREAM=$(git -C "$GIT_DIR" --no-optional-locks rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
  if [ -n "$UPSTREAM" ]; then
    GIT_AHEAD=$(git -C "$GIT_DIR" --no-optional-locks rev-list "@{upstream}..HEAD" --count 2>/dev/null || echo 0)
    GIT_BEHIND=$(git -C "$GIT_DIR" --no-optional-locks rev-list "HEAD..@{upstream}" --count 2>/dev/null || echo 0)
  fi
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
LINE1+="${CTX_COLOR}[${BAR_FILLED}${BAR_EMPTY}] ${CTX_PCT_FMT}${RESET}${GRAY}/${CTX_SIZE_FMT}${RESET}"
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
  local pct_int=$(echo "$pct" | cut -d. -f1)
  local filled=$(( (pct_int * 8 + 50) / 100 ))
  [ "$filled" -gt 8 ] && filled=8
  [ "$filled" -lt 0 ] && filled=0
  local empty=$(( 8 - filled ))
  local bar=""
  local i=0
  while [ "$i" -lt "$filled" ]; do bar+="#"; i=$(( i + 1 )); done
  i=0
  while [ "$i" -lt "$empty" ]; do bar+="-"; i=$(( i + 1 )); done
  echo "$bar"
}

# Helper: color for rate limit (simple threshold fallback)
rl_color() {
  local pct_int=$(echo "${1:-0}" | cut -d. -f1)
  if   [ "$pct_int" -ge 80 ]; then echo "$RED"
  elif [ "$pct_int" -ge 50 ]; then echo "$YELLOW"
  else echo "$GREEN"; fi
}

# Helper: time-paced color — green=under, yellow=on, red=over schedule
# Args: usage_pct reset_at_epoch window_secs
rl_color_timed() {
  local usage_int=$(echo "${1:-0}" | cut -d. -f1)
  local reset_at="${2:-0}"
  local window="${3:-18000}"
  if [ -n "$reset_at" ] && [ "$reset_at" -gt 0 ] 2>/dev/null; then
    local now=$(date +%s)
    local elapsed=$(( window - (reset_at - now) ))
    [ "$elapsed" -lt 0 ] && elapsed=0
    local time_pct=$(( elapsed * 100 / window ))
    local delta=$(( usage_int - time_pct ))
    if   [ "$delta" -gt 30 ]; then echo "$RED"
    elif [ "$delta" -gt 10 ]; then echo "$MAGENTA"
    elif [ "$delta" -gt -10 ]; then echo "$YELLOW"
    elif [ "$delta" -gt -30 ]; then echo "$GREEN"
    else echo "$CYAN"; fi
  else
    rl_color "$1"
  fi
}

# ── Helper: format pct with fixed 3-char width ───────────
fmt_pct() { local v=$(( ${1%%.*} > 999 ? 999 : (${1%%.*} < 0 ? 0 : ${1%%.*}) )); printf "%3d%%" "$v"; }

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
  LINE3+="${GRAY}5h ${RESET}${RL5H_COLOR}[${RL5H_BAR}] $(fmt_pct $RL5H_INT)${RESET}${RL5H_RESET_FMT}"
fi

# ── 7-day rate limit ──────────────────────────────────────
if [ -n "$RL7D_PCT" ]; then
  RL7D_INT=$(echo "$RL7D_PCT" | cut -d. -f1)
  RL7D_COLOR=$(rl_color_timed "$RL7D_PCT" "$RL7D_RESET" 604800)
  RL7D_BAR=$(rl_bar "$RL7D_PCT")
  RL7D_RESET_FMT=""
  [ -n "$RL7D_RESET" ] && RL7D_RESET_FMT=" ${GRAY}->${RESET} ${CYAN}$(fmt_reset "$RL7D_RESET")${RESET}"
  [ -n "$LINE3" ] && LINE3+="$SEP"
  LINE3+="${GRAY}7d ${RESET}${RL7D_COLOR}[${RL7D_BAR}] $(fmt_pct $RL7D_INT)${RESET}${RL7D_RESET_FMT}"
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
  MONTHLY_COST=$(grep -h "." "$USAGE_FILE" 2>/dev/null \
    | jq -r --arg m "$THIS_MONTH" \
      'select(.timestamp | startswith($m)) | .costUSD // .cost_usd // 0' \
    | awk '{s+=$1} END {printf "%.3f", s+0}' 2>/dev/null || echo "")
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
if [ -n "$CODEX_QUOTA" ] && echo "$CODEX_QUOTA" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'primary_pct' in d else 1)" 2>/dev/null; then
  CX_PRI=$(echo "$CODEX_QUOTA"      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['primary_pct'])")
  CX_PRI_AT=$(echo "$CODEX_QUOTA"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['primary_reset_at'])")
  CX_PRI_RST=$(echo "$CODEX_QUOTA"  | python3 -c "import sys,json; d=json.load(sys.stdin); s=d['primary_reset_secs']; d2=s//86400; h=(s%86400)//3600; m=(s%3600)//60; t=f'{d2}d{h}h' if d2>0 else (f'{h}h{m}m' if h>0 else f'{m}m'); print(f'{t:>6}')")
  CX_SEC=$(echo "$CODEX_QUOTA"      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['secondary_pct'])")
  CX_SEC_AT=$(echo "$CODEX_QUOTA"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['secondary_reset_at'])")
  CX_SEC_RST=$(echo "$CODEX_QUOTA"  | python3 -c "import sys,json; d=json.load(sys.stdin); s=d['secondary_reset_secs']; d2=s//86400; h=(s%86400)//3600; m=(s%3600)//60; t=f'{d2}d{h}h' if d2>0 else (f'{h}h{m}m' if h>0 else f'{m}m'); print(f'{t:>6}')")
  CX_LIM=$(echo "$CODEX_QUOTA"      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['limit_reached'])")

  if [ "$CX_LIM" = "True" ]; then
    CX_PRI_INT=$(echo "$CX_PRI" | cut -d. -f1)
    CX_SEC_INT=$(echo "$CX_SEC" | cut -d. -f1)
    if [ "$CX_PRI_INT" -lt 100 ] && [ "$CX_SEC_INT" -lt 100 ]; then
      CX_PRI=100
    fi
  fi

  # Time-paced color — same logic as Claude
  CX_PRI_COLOR=$(rl_color_timed "$CX_PRI" "$CX_PRI_AT" 18000)
  CX_PRI_BAR=$(rl_bar "$CX_PRI")
  CX_SEC_COLOR=$(rl_color_timed "$CX_SEC" "$CX_SEC_AT" 604800)
  CX_SEC_BAR=$(rl_bar "$CX_SEC")

  LINE4="${TEAL}</>${RESET} ${GRAY}5h ${RESET}${CX_PRI_COLOR}[${CX_PRI_BAR}] $(fmt_pct $CX_PRI)${RESET} ${GRAY}->${RESET} ${CYAN}${CX_PRI_RST}${RESET}"
  LINE4+="$SEP"
  LINE4+="${GRAY}7d ${RESET}${CX_SEC_COLOR}[${CX_SEC_BAR}] $(fmt_pct $CX_SEC)${RESET} ${GRAY}->${RESET} ${CYAN}${CX_SEC_RST}${RESET}"
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
