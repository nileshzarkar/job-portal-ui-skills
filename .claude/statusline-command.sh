#!/bin/bash
input=$(cat)

# Parse all fields in one node call (jq isn't available on this machine)
read -r MODEL DIR COST PCT DURATION_MS < <(node -e '
  let d = ""; process.stdin.on("data", c => d += c).on("end", () => {
    const j = JSON.parse(d || "{}");
    const model = (j.model?.display_name || "").split(" ")[0] || "-";
    const dir = j.workspace?.current_dir || "";
    const cost = j.cost?.total_cost_usd ?? 0;
    const pct = Math.floor(j.context_window?.used_percentage ?? 0);
    const dur = j.cost?.total_duration_ms ?? 0;
    process.stdout.write([model, dir, cost, pct, dur].join(" "));
  });
' <<< "$input")

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

# Pick bar color based on context usage
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

echo -e "${CYAN}[$MODEL]${RESET} 📁 ${DIR##*/}$BRANCH"
COST_FMT=$(printf '$%.2f' "$COST")
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s"