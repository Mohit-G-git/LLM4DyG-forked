#!/bin/bash
# Run remaining 5 Fig3 tasks: which_neighbor, check_tclosure, check_tpath, find_tpath, sort_edge
# Uses existing vicuna-7b server running on localhost:8000
# Saves to separate logs/fig3_remaining directory (not logs/fig3)
# 100 instances per task to match your existing tasks

# ============================================================================
# SETUP
# ============================================================================

set -e

# Configuration
MODEL="vicuna-7b"
N=10
NUM_SEED=100      # 100 instances per config (matches your existing tasks)
K=2
T_VALUES=(10 20 30)
P_VALUES=(0.3 0.5 0.7)

# Remaining 5 tasks to execute
REMAINING_TASKS=("which_neighbor" "check_tclosure" "check_tpath" "find_tpath" "sort_edge")

# Output directory (separate from logs/fig3)
LOGS_BASE="logs/fig3_remaining"
mkdir -p "$LOGS_BASE"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
    echo -e "[$(date +%H:%M:%S)] $1"
}

log_ok() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] ✅ $1${NC}"
}

log_err() {
    echo -e "${RED}[$(date +%H:%M:%S)] ❌ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠️  $1${NC}"
}

log_info() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] ℹ️  $1${NC}"
}

# Check if server is running
check_server() {
    log_info "Checking if vicuna-7b server is running..."
    if curl -s http://localhost:8000/v1/models &>/dev/null; then
        log_ok "Server is running ✅"
        return 0
    else
        log_err "Server NOT running!"
        log "Start it in another terminal with:"
        log ""
        log "  source .venv/bin/activate"
        log "  python3 scripts/example/start_server.py --model vicuna-7b -t run --device 0"
        log ""
        exit 1
    fi
}

# Get accuracy from results file
get_accuracy() {
    local task=$1
    local result_file="$LOGS_BASE/$task/results_${MODEL}.json"
    
    if [[ -f "$result_file" ]]; then
        python3 -c "
import json
try:
    with open('$result_file', 'r') as f:
        data = json.load(f)
        acc = data.get('average_acc', 0)
        fail = data.get('fail_rate', 0)
        print(f'{acc:.4f}|{fail:.4f}')
except:
    print('ERROR|ERROR')
" 2>/dev/null || echo "ERROR|ERROR"
    else
        echo "N/A|N/A"
    fi
}

# Run single task (gen → run → eval)
run_task() {
    local TASK=$1
    
    log_ok "===== TASK: $TASK ====="
    log "Running with 100 instances, T=[10,20,30], P=[0.3,0.5,0.7]"
    log ""
    
    # Step 1: Generate data for all T×P combinations
    log_info "STEP 1: Generating data (gen)..."
    for T in "${T_VALUES[@]}"; do
        for P in "${P_VALUES[@]}"; do
            P_CLEAN=${P//./}
            LOGDIR="$LOGS_BASE/$TASK/T${T}_p${P_CLEAN}"
            
            python3 scripts/example/run_one_task.py \
                --task "$TASK" --model "$MODEL" \
                --N "$N" --T "$T" --p "$P" \
                --num_seed "$NUM_SEED" --k "$K" \
                --log_dir "$LOGDIR" -t gen 2>&1 | tail -3
        done
    done
    log_ok "Data generation complete"
    
    # Step 2: Run inference for all T×P combinations
    log_info "STEP 2: Running inference (run)..."
    for T in "${T_VALUES[@]}"; do
        for P in "${P_VALUES[@]}"; do
            P_CLEAN=${P//./}
            LOGDIR="$LOGS_BASE/$TASK/T${T}_p${P_CLEAN}"
            config_name="T${T}_p${P_CLEAN}"
            
            log "  Running inference for $config_name..."
            python3 scripts/example/run_one_task.py \
                --task "$TASK" --model "$MODEL" \
                --N "$N" --T "$T" --p "$P" \
                --num_seed "$NUM_SEED" --k "$K" \
                --log_dir "$LOGDIR" -t run 2>&1 | tail -3 || log_warn "Inference may have issues for $config_name"
        done
    done
    log_ok "Inference complete"
    
    # Step 3: Evaluate all T×P combinations
    log_info "STEP 3: Evaluating results (eval)..."
    for T in "${T_VALUES[@]}"; do
        for P in "${P_VALUES[@]}"; do
            P_CLEAN=${P//./}
            LOGDIR="$LOGS_BASE/$TASK/T${T}_p${P_CLEAN}"
            
            python3 scripts/example/run_one_task.py \
                --task "$TASK" --model "$MODEL" \
                --N "$N" --T "$T" --p "$P" \
                --num_seed "$NUM_SEED" --k "$K" \
                --log_dir "$LOGDIR" -t eval 2>&1 | tail -3
        done
    done
    log_ok "Evaluation complete"
    
    # Step 4: Check accuracy
    log_info "STEP 4: Checking accuracy..."
    ACC_FAIL=$(get_accuracy "$TASK")
    ACC=$(echo "$ACC_FAIL" | cut -d'|' -f1)
    FAIL=$(echo "$ACC_FAIL" | cut -d'|' -f2)
    
    if [[ "$ACC" == "N/A" ]]; then
        log_warn "Results not yet available"
    elif [[ "$ACC" == "ERROR" ]]; then
        log_err "ERROR reading results!"
        return 1
    else
        ACC_PCT=$(echo "scale=1; $ACC * 100" | bc 2>/dev/null || echo "0")
        FAIL_PCT=$(echo "scale=1; $FAIL * 100" | bc 2>/dev/null || echo "0")
        
        if (( $(echo "$ACC < 0" | bc -l) )); then
            log_err "[$TASK] ACCURACY: ${ACC_PCT}% | FAIL_RATE: ${FAIL_PCT}% - ❌ NO RESULTS"
            return 1
        elif (( $(echo "$ACC < 0.2" | bc -l) )); then
            log_err "[$TASK] ACCURACY: ${ACC_PCT}% | FAIL_RATE: ${FAIL_PCT}% - ❌ CRITICAL (check errors)"
            return 1
        elif (( $(echo "$ACC < 0.5" | bc -l) )); then
            log_warn "[$TASK] ACCURACY: ${ACC_PCT}% | FAIL_RATE: ${FAIL_PCT}% - ⚠️  LOW"
        elif (( $(echo "$ACC < 0.7" | bc -l) )); then
            log_ok "[$TASK] ACCURACY: ${ACC_PCT}% | FAIL_RATE: ${FAIL_PCT}% - ✅ FAIR"
        else
            log_ok "[$TASK] ACCURACY: ${ACC_PCT}% | FAIL_RATE: ${FAIL_PCT}% - ✅ GOOD"
        fi
    fi
    
    echo ""
    sleep 2  # Small delay between tasks
}

# Run all tasks sequentially
run_all_tasks() {
    log_ok "╔════════════════════════════════════════════════════════╗"
    log_ok "║   Running 5 Remaining Fig3 Tasks (Sequential)          ║"
    log_ok "║   which_neighbor, check_tclosure, check_tpath,         ║"
    log_ok "║   find_tpath, sort_edge                                 ║"
    log_ok "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    local success_count=0
    local fail_count=0
    
    for TASK in "${REMAINING_TASKS[@]}"; do
        if run_task "$TASK"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    log_ok "╔════════════════════════════════════════════════════════╗"
    log_ok "║             EXECUTION COMPLETE                         ║"
    log_ok "╚════════════════════════════════════════════════════════╝"
    
    log_info "Results saved to: $LOGS_BASE"
    log_info "Tasks completed: $success_count / ${#REMAINING_TASKS[@]}"
    
    if [[ $fail_count -gt 0 ]]; then
        log_warn "Failed tasks: $fail_count (check logs above)"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    log_info "LLM4DyG - Run Remaining 5 Fig3 Tasks"
    log_info "Model: $MODEL | Instances: $NUM_SEED | Configs: 9 per task"
    log_info "Total: 5 tasks × 9 configs × 100 instances = 4,500 QA pairs"
    echo ""
    
    # Check prerequisites
    check_server
    
    # Run all tasks
    run_all_tasks
}

# ============================================================================
# RUN
# ============================================================================

main "$@"
