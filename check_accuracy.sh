#!/bin/bash
# Quick Accuracy Checker for LLM4DyG Fig3 Tasks
# Shows real-time accuracy status across all tasks
# Usage: bash check_accuracy.sh

MODEL="vicuna-7b"
TASKS=("when_link" "when_connect" "when_tclosure" "what_node" "which_neighbor" "check_tclosure" "check_tpath" "find_tpath" "sort_edge")

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           LLM4DyG FIG3 ACCURACY CHECK                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create results table
printf "%-20s | %-12s | %-12s | %-12s\n" "TASK" "ACCURACY" "FAIL_RATE" "STATUS"
printf "%s\n" "$(printf '%.0s-' {1..65})"

total_acc=0
count=0

for TASK in "${TASKS[@]}"; do
    result_file="logs/fig3/$TASK/results_${MODEL}.json"
    
    if [[ ! -f "$result_file" ]]; then
        printf "%-20s | %-12s | %-12s | %s\n" "$TASK" "PENDING" "-" "⏳ Not done"
    else
        acc=$(python3 -c "import json; data=json.load(open('$result_file')); print(f\"{data.get('average_acc', 0):.4f}\")" 2>/dev/null || echo "ERROR")
        fail=$(python3 -c "import json; data=json.load(open('$result_file')); print(f\"{data.get('fail_rate', 0):.4f}\")" 2>/dev/null || echo "ERROR")
        
        if [[ "$acc" == "ERROR" ]]; then
            printf "%-20s | %-12s | %-12s | %s\n" "$TASK" "ERROR" "-" "❌ Parse error"
        else
            acc_pct=$(echo "scale=1; $acc * 100" | bc)
            fail_pct=$(echo "scale=1; $fail * 100" | bc)
            
            if (( $(echo "$acc < 0.2" | bc -l) )); then
                status="❌ VERY LOW"
                color=$RED
            elif (( $(echo "$acc < 0.5" | bc -l) )); then
                status="⚠️  LOW"
                color=$YELLOW
            elif (( $(echo "$acc < 0.7" | bc -l) )); then
                status="✅ FAIR"
                color=$BLUE
            else
                status="✅ GOOD"
                color=$GREEN
            fi
            
            printf "${color}%-20s | %5.1f%%       | %5.1f%%       | %s${NC}\n" "$TASK" "$acc_pct" "$fail_pct" "$status"
            
            total_acc=$(echo "$total_acc + $acc" | bc)
            ((count++))
        fi
    fi
done

printf "%s\n" "$(printf '%.0s-' {1..65})"

if [[ $count -gt 0 ]]; then
    avg_acc=$(echo "scale=4; $total_acc / $count" | bc)
    avg_pct=$(echo "scale=1; $avg_acc * 100" | bc)
    printf "${GREEN}%-20s | %5.1f%%       |            | AVERAGE${NC}\n" "ALL TASKS" "$avg_pct"
fi

echo ""
echo "Legend:"
echo "  ✅ GOOD  : Accuracy >= 70% (Reliable)"
echo "  ✅ FAIR  : Accuracy 50-70% (Acceptable)"
echo "  ⚠️  LOW   : Accuracy 20-50% (Debug needed)"
echo "  ❌ VERY LOW: Accuracy < 20% (Major issues)"
echo "  ⏳ PENDING: Task not yet evaluated"
echo ""
