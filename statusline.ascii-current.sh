#!/bin/bash
# ✨ Fancy Claude Code Status Line
# Install: chmod +x ~/.claude/statusline.sh
# Settings: { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0, "refreshInterval": 5 } }

input=$(cat)

# ── Caveman State ────────────────────────────────────────
CAVEMAN_FLAG="$HOME/.claude/.caveman-active"
CAVEMAN_MODE=""
if [ -f "$CAVEMAN_FLAG" ]; then
  CAVEMAN_MODE=$(tr -d '[:space:]' < "$CAVEMAN_FLAG" 2>/dev/null | tr '[:lower:]' '[:upper:]')
fi

# ── Ponytail State ───────────────────────────────────────
PONYTAIL_FLAG="$HOME/.claude/.ponytail-active"
PONYTAIL_MODE=""
if [ -f "$PONYTAIL_FLAG" ]; then
  PONYTAIL_MODE=$(head -n1 "$PONYTAIL_FLAG" 2>/dev/null | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
fi

# ── Colors ──────────────────────────────────────────────
RESET="\033[0m"
BOLD=""
DIM="\033[2m"

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
LIME="\033[38;5;118m"
GOLD="\033[38;5;220m"
PINK="\033[38;5;198m"

# ── Single jq parse (was 14 separate calls) ──────────────
{
  IFS= read -r MODEL
  IFS= read -r CTX_PCT
  IFS= read -r CTX_SIZE
  IFS= read -r COST
  IFS= read -r DURATION_MS
  IFS= read -r LINES_ADD
  IFS= read -r LINES_DEL
  IFS= read -r CWD
  IFS= read -r PROJECT_DIR
  IFS= read -r WORKTREE
  IFS= read -r RL5H_PCT
  IFS= read -r RL5H_RESET
  IFS= read -r RL7D_PCT
  IFS= read -r RL7D_RESET
  IFS= read -r SESSION_NAME
} < <(jq -r '
  (.model.display_name // "unknown"),
  ((.context_window.used_percentage // 0) | floor | tostring),
  (.context_window.context_window_size // 0 | tostring),
  (.cost.total_cost_usd // 0 | tostring),
  (.cost.total_duration_ms // 0 | tostring),
  (.cost.total_lines_added // 0 | tostring),
  (.cost.total_lines_removed // 0 | tostring),
  (.workspace.current_dir // ""),
  (.workspace.project_dir // ""),
  (.workspace.git_worktree // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.rate_limits.seven_day.resets_at // ""),
  (.session_name // "")
' <<< "$input")

# ── Derived Values ───────────────────────────────────────
COST_FMT=$(printf "%.3f" "$COST" 2>/dev/null || echo "0.000")

DURATION_SEC=$(( DURATION_MS / 1000 ))
if [ "$DURATION_SEC" -ge 3600 ]; then
  DURATION_FMT=$(printf "%dh%02dm" "$(( DURATION_SEC / 3600 ))" "$(( (DURATION_SEC % 3600) / 60 ))")
elif [ "$DURATION_SEC" -ge 60 ]; then
  DURATION_FMT=$(printf "%dm%02ds" "$(( DURATION_SEC / 60 ))" "$(( DURATION_SEC % 60 ))")
else
  DURATION_FMT="${DURATION_SEC}s"
fi

if [ "$CTX_SIZE" -ge 1000000 ]; then
  CTX_SIZE_FMT="1M"
elif [ "$CTX_SIZE" -ge 1000 ]; then
  CTX_SIZE_FMT="$(( CTX_SIZE / 1000 ))k"
else
  CTX_SIZE_FMT="${CTX_SIZE}"
fi

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

COST_INT="${COST%%.*}"
if [ "${COST_INT:-0}" -ge 5 ] 2>/dev/null; then
  COST_COLOR="$RED"
elif [ "${COST_INT:-0}" -ge 1 ] 2>/dev/null; then
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
  GIT_STAGED=$(git -C "$GIT_DIR" --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l)
  GIT_STAGED="${GIT_STAGED// /}"
  GIT_UNSTAGED=$(git -C "$GIT_DIR" --no-optional-locks diff --numstat 2>/dev/null | wc -l)
  GIT_UNSTAGED="${GIT_UNSTAGED// /}"
  GIT_UNTRACKED=$(git -C "$GIT_DIR" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | wc -l)
  GIT_UNTRACKED="${GIT_UNTRACKED// /}"
  UPSTREAM=$(git -C "$GIT_DIR" --no-optional-locks rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
  if [ -n "$UPSTREAM" ]; then
    GIT_AHEAD=$(git -C "$GIT_DIR" --no-optional-locks rev-list "@{upstream}..HEAD" --count 2>/dev/null || echo 0)
    GIT_BEHIND=$(git -C "$GIT_DIR" --no-optional-locks rev-list "HEAD..@{upstream}" --count 2>/dev/null || echo 0)
  fi
fi

# ── Model short name ─────────────────────────────────────
MODEL_SHORT="${MODEL#Claude }"
MODEL_SHORT="${MODEL_SHORT#claude-}"

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
if [ -n "$PONYTAIL_MODE" ]; then
  if [ "$PONYTAIL_MODE" = "FULL" ]; then
    LINE1+="${BOLD}\033[38;5;108m[PONYTAIL]${RESET}"
  else
    LINE1+="${BOLD}\033[38;5;108m[PONYTAIL:${PONYTAIL_MODE}]${RESET}"
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

if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
  LINE1+="$SEP"
  LINE1+="${GREEN}+${LINES_ADD}${RESET}${GRAY}/${RESET}${RED}-${LINES_DEL}${RESET}"
fi

# ── Line 2: Git ───────────────────────────────────────────
LINE2=""
if $IS_GIT; then
  LINE2+="${BOLD}${BLUE}[/] ${FOLDER}${RESET}"
  LINE2+=" ${GRAY}@${RESET} "

  if [ -n "$WORKTREE" ]; then
    LINE2+="${CYAN}${GIT_BRANCH}${RESET}${GRAY}[wt:${WORKTREE}]${RESET}"
  else
    LINE2+="${CYAN}${GIT_BRANCH}${RESET}"
  fi

  if [ "$GIT_AHEAD" -gt 0 ] && [ "$GIT_BEHIND" -gt 0 ]; then
    LINE2+=" ${YELLOW}^${GIT_AHEAD}v${GIT_BEHIND}${RESET}"
  elif [ "$GIT_AHEAD" -gt 0 ]; then
    LINE2+=" ${GREEN}^${GIT_AHEAD}${RESET}"
  elif [ "$GIT_BEHIND" -gt 0 ]; then
    LINE2+=" ${RED}v${GIT_BEHIND}${RESET}"
  fi

  LINE2+="$SEP"

  GIT_PARTS=""
  [ "$GIT_STAGED" -gt 0 ]    && GIT_PARTS+="${GREEN}+${GIT_STAGED}${RESET} "
  [ "$GIT_UNSTAGED" -gt 0 ]  && GIT_PARTS+="${YELLOW}~${GIT_UNSTAGED}${RESET} "
  [ "$GIT_UNTRACKED" -gt 0 ] && GIT_PARTS+="${GRAY}?${GIT_UNTRACKED}${RESET} "

  if [ -n "$GIT_PARTS" ]; then
    LINE2+="$GIT_PARTS"
  else
    LINE2+="${GREEN}.${RESET}"
  fi
else
  LINE2+="${BOLD}${BLUE}[/] ${FOLDER}${RESET}${GRAY} (no git)${RESET}"
fi

[ -n "$SESSION_NAME" ] && LINE2+="${SEP}${GRAY}#${SESSION_NAME}${RESET}"

# ── Line 3: Usage / Rate Limits ──────────────────────────
LINE3=""

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

rl_bar() {
  local pct="${1:-0}"
  local pct_int=$(pct_int "$pct")
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

rl_color() {
  local pct_int=$(pct_int "$1")
  if   [ "$pct_int" -ge 98 ]; then echo "$RED"
  elif [ "$pct_int" -ge 90 ]; then echo "$PINK"
  elif [ "$pct_int" -ge 80 ]; then echo "$MAGENTA"
  elif [ "$pct_int" -ge 70 ]; then echo "$ORANGE"
  elif [ "$pct_int" -ge 60 ]; then echo "$GOLD"
  elif [ "$pct_int" -ge 50 ]; then echo "$YELLOW"
  elif [ "$pct_int" -ge 40 ]; then echo "$LIME"
  elif [ "$pct_int" -ge 30 ]; then echo "$GREEN"
  elif [ "$pct_int" -ge 20 ]; then echo "$TEAL"
  elif [ "$pct_int" -ge 10 ]; then echo "$CYAN"
  else echo "$BLUE"; fi
}

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
    elif [ "$delta" -gt 30 ]; then echo "$PINK"
    elif [ "$delta" -gt 22 ]; then echo "$MAGENTA"
    elif [ "$delta" -gt 15 ]; then echo "$ORANGE"
    elif [ "$delta" -gt 8 ]; then echo "$GOLD"
    elif [ "$delta" -gt 2 ]; then echo "$YELLOW"
    elif [ "$delta" -gt -4 ]; then echo "$LIME"
    elif [ "$delta" -gt -10 ]; then echo "$GREEN"
    elif [ "$delta" -gt -18 ]; then echo "$TEAL"
    elif [ "$delta" -gt -28 ]; then echo "$CYAN"
    else echo "$BLUE"; fi
  else
    rl_color "$1"
  fi
}

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

fmt_secs() {
  local s="$1"
  local d=$(( s / 86400 ))
  local h=$(( (s % 86400) / 3600 ))
  local m=$(( (s % 3600) / 60 ))
  if   [ "$d" -gt 0 ]; then printf "%-6s" "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then printf "%-6s" "${h}h${m}m"
  else printf "%-6s" "${m}m"; fi
}

if [ -n "$RL5H_PCT" ]; then
  RL5H_COLOR=$(rl_color_timed "$RL5H_PCT" "$RL5H_RESET" 18000)
  RL5H_BAR=$(rl_bar "$RL5H_PCT")
  RL5H_RESET_FMT=""
  [ -n "$RL5H_RESET" ] && RL5H_RESET_FMT=" ${GRAY}->${RESET} ${CYAN}$(fmt_reset "$RL5H_RESET")${RESET}"
  LINE3+="${GRAY}5h ${RESET}${RL5H_COLOR}[${RL5H_BAR}] $(fmt_pct $RL5H_PCT)${RESET}${RL5H_RESET_FMT}"
fi

if [ -n "$RL7D_PCT" ]; then
  RL7D_COLOR=$(rl_color_timed "$RL7D_PCT" "$RL7D_RESET" 604800)
  RL7D_BAR=$(rl_bar "$RL7D_PCT")
  RL7D_RESET_FMT=""
  [ -n "$RL7D_RESET" ] && RL7D_RESET_FMT=" ${GRAY}->${RESET} ${CYAN}$(fmt_reset "$RL7D_RESET")${RESET}"
  [ -n "$LINE3" ] && LINE3+="$SEP"
  LINE3+="${GRAY}7d ${RESET}${RL7D_COLOR}[${RL7D_BAR}] $(fmt_pct $RL7D_PCT)${RESET}${RL7D_RESET_FMT}"
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
  MONTHLY_COST=$(jq -rR --arg m "$THIS_MONTH" \
    'try fromjson | select(.timestamp | startswith($m)) | .costUSD // .cost_usd // 0' \
    "$USAGE_FILE" 2>/dev/null \
    | awk '{s+=$1} END {printf "%.3f", s+0}' 2>/dev/null || echo "")
  if [ -n "$MONTHLY_COST" ] && [ "$MONTHLY_COST" != "0.000" ]; then
    MONTHLY_INT="${MONTHLY_COST%%.*}"
    if   [ "${MONTHLY_INT:-0}" -ge 50 ] 2>/dev/null; then MONTHLY_COLOR="$RED"
    elif [ "${MONTHLY_INT:-0}" -ge 20 ] 2>/dev/null; then MONTHLY_COLOR="$YELLOW"
    else MONTHLY_COLOR="$GREEN"; fi
    [ -n "$LINE3" ] && LINE3+="$SEP"
    LINE3+="${GRAY}$(date +%b) ${RESET}${MONTHLY_COLOR}\$${MONTHLY_COST}${RESET}"
  fi
fi

[ -n "$LINE3" ] && LINE3="${ORANGE}(C)${RESET} ${LINE3}"

# ── Line 4: Codex Quota (was 9 python3 calls → 1) ────────
LINE4=""
CODEX_PARSED=$(python3 - 2>/dev/null << 'PYEOF'
import sys, os, json

sys.path.insert(0, os.path.expanduser('~/.claude'))
try:
    import codex_quota
    d = codex_quota.load_cache()
    if d is None:
        d = codex_quota.fetch_quota()
except Exception:
    sys.exit(1)

if 'primary_pct' not in d:
    sys.exit(1)

def fmt(secs):
    try: secs = int(secs)
    except: return '    --'
    d2, r = divmod(secs, 86400)
    h, r = divmod(r, 3600)
    m = r // 60
    t = f'{d2}d{h}h' if d2 else (f'{h}h{m}m' if h else f'{m}m')
    return f'{t:>6}'

print(d.get('primary_pct', 0))
print(d.get('primary_reset_at', 0))
print(fmt(d.get('primary_reset_secs', 0)))
print(d.get('primary_window_secs', 0))
print(d.get('has_primary', False))
print(d.get('secondary_pct', 0))
print(d.get('secondary_reset_at', 0))
print(fmt(d.get('secondary_reset_secs', 0)))
print(d.get('secondary_window_secs', 0))
print(d.get('has_secondary', False))
print(d.get('limit_reached', False))
PYEOF
)

if [ -n "$CODEX_PARSED" ]; then
  {
    IFS= read -r CX_PRI
    IFS= read -r CX_PRI_AT
    IFS= read -r CX_PRI_RST
    IFS= read -r CX_PRI_WIN
    IFS= read -r CX_HAS_PRI
    IFS= read -r CX_SEC
    IFS= read -r CX_SEC_AT
    IFS= read -r CX_SEC_RST
    IFS= read -r CX_SEC_WIN
    IFS= read -r CX_HAS_SEC
    IFS= read -r CX_LIM
  } <<< "$CODEX_PARSED"

  if [ "$CX_LIM" = "True" ]; then
    CX_PRI_INT="${CX_PRI%%.*}"
    [[ "$CX_PRI_INT" =~ ^-?[0-9]+$ ]] || CX_PRI_INT=0
    [ "$CX_PRI_INT" -lt 100 ] && CX_PRI=100
  fi

  # Label each window by its actual seconds — Codex doesn't always put the
  # 5h window in "primary" and 7d in "secondary".
  win_label() { [ "${1:-0}" -gt 0 ] 2>/dev/null && [ "$1" -le 21600 ] && echo "5h" || echo "7d"; }

  if [ "$CX_HAS_PRI" = "True" ]; then
    CX_PRI_LABEL=$(win_label "$CX_PRI_WIN")
    CX_PRI_COLOR=$(rl_color_timed "$CX_PRI" "$CX_PRI_AT" "${CX_PRI_WIN:-18000}")
    CX_PRI_BAR=$(rl_bar "$CX_PRI")
    LINE4+="${TEAL}</>${RESET} ${GRAY}${CX_PRI_LABEL} ${RESET}${CX_PRI_COLOR}[${CX_PRI_BAR}] $(fmt_pct $CX_PRI)${RESET} ${GRAY}->${RESET} ${CYAN}${CX_PRI_RST}${RESET}"
  fi

  if [ "$CX_HAS_SEC" = "True" ]; then
    CX_SEC_LABEL=$(win_label "$CX_SEC_WIN")
    CX_SEC_COLOR=$(rl_color_timed "$CX_SEC" "$CX_SEC_AT" "${CX_SEC_WIN:-604800}")
    CX_SEC_BAR=$(rl_bar "$CX_SEC")
    [ -n "$LINE4" ] && LINE4+="$SEP" || LINE4+="${TEAL}</>${RESET} "
    LINE4+="${GRAY}${CX_SEC_LABEL} ${RESET}${CX_SEC_COLOR}[${CX_SEC_BAR}] $(fmt_pct $CX_SEC)${RESET} ${GRAY}->${RESET} ${CYAN}${CX_SEC_RST}${RESET}"
  fi
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
