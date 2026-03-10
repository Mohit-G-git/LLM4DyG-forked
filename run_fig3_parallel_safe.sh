#!/bin/bash
# OPTIMIZED for shared GPU with accuracy monitoring
# Prevents 0% accuracy from parallel GPU thrashing
# Usage: bash run_fig3_parallel_safe.sh

set -e

MODEL="vicuna-7b"
N=10
NUM_SEED=100
K=2
T_VALUES=(10 20 30)
P_VALUES=(0.3 0.5 0.7)

# All 9 Fig3 tasks
TASKS=("when_link" "when_connect" "when_tclosure" "what_node" "which_neighbor" "check_tclosure" "check_tpath" "find_tpath" "sort_edge")

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_DIR="logs/run_parallel_safe"
mkdir -p "$LOG_DIR"
MASTER_LOG="$LOG_DIR/master_$(date +%Y%m%d_%H%M%S).log"
ACCURACY_LOG="$LOG_DIR/accuracy_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date +%H:%M:%S)] $1" | tee -a "$MASTER_LOG"
}

log_success() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] ✅ $1${NC}" | tee -a "$MASTER_LOG"
}

log_error() {
    echo -e "${RED}[$(date +%H:%M:%S)] ❌ $1${NC}" | tee -a "$MASTER_LOG"
}

log_warning() {
    echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠️  $1${NC}" | tee -a "$MASTER_LOG"
}

log_info() {
    echo -e "${BLUE}[$(date +%H:%M:%S)] ℹ️  $1${NC}" | tee -a "$MASTER_LOG"
}

# Check GPU availability
check_gpu() {
    log_info "========== GPU CHECK =========="
    if command -v nvidia-smi &> /dev/null; then
        GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
        log_info "Found $GPU_COUNT GPU(s)"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | tee -a "$MASTER_LOG"
    else
        log_warning "nvidia-smi not found, assuming CPU mode"
    fi
}

# Monitor GPU during run
monitor_gpu() {
    local task_name=$1
    if command -v nvidia-smi &> /dev/null; then
        log_info "GPU status for $task_name:"
        nvidia-smi --query-gpu=memory.used,memory.free,utilization.gpu --format=csv,noheader | tee -a "$MASTER_LOG"
    fi
}

# Check accuracy after eval
check_accuracy() {
    local task=$1
    local result_file="logs/fig3/$task/results_${MODEL}.json"
    
    if [[ ! -f "$result_file" ]]; then
        log_error "Results file not found: $result_file"
        echo "ERROR"
        return 1
    fi
    
    # Extract accuracy using python for reliability
    python3 -c "
import json
with open('$result_file', 'r') as f:
    data = json.load(f)
    print(f\"{data.get('average_acc', 'ERROR')}\")
" 2>/dev/null || echo "ERROR"
}

# Get fail rate after eval
check_fail_rate() {
    local task=$1
    local result_file="logs/fig3/$task/results_${MODEL}.json"
    
    if [[ ! -f "$result_file" ]]; then
        return 1
    fi
    
    python3 -c "
import json
with open('$result_file', 'r') as f:
    data = json.load(f)
    print(f\"{data.get('fail_rate', 'ERROR')}\")
" 2>/dev/null || echo "ERROR"
}

# Phase 1: Generate all data (parallel - safe)
phase1_gen_all() {
    log_success "========== PHASE 1: GENERATE DATA (Parallel - Safe) =========="
    log_info "Generating data for all ${#TASKS[@]} tasks in parallel..."
    
    local pids=()
    for TASK in "${TASKS[@]}"; do
        (
            log_info "[$TASK] Starting data generation for all T×p combinations..."
            local gen_count=0
            for T in "${T_VALUES[@]}"; do
                for P in "${P_VALUES[@]}"; do
                    P_CLEAN=${P//./}
                    LOGDIR="logs/fig3/$TASK/T${T}_p${P_CLEAN}"
                    python scripts/example/run_one_task.py \
                        --task "$TASK" --model "$MODEL" \
                        --N "$N" --T "$T" --p "$P" \
                        --num_seed "$NUM_SEED" --k "$K" \
                        --log_dir "$LOGDIR" -t gen 2>&1 >/dev/null
                    ((gen_count++))
                    log_info "[$TASK] Generated T=$T p=$P ($gen_count/9)"
                done
            done
            log_success "[$TASK] Data generation complete (9 configs)"
        ) &
        pids+=($!)
    done
    
    log_info "Waiting for all ${#pids[@]} generation tasks to complete..."
    for pid in "${pids[@]}"; do
        wait "$pid" || log_warning "Generation task (PID $pid) exited with error"
    done
    
    log_success "========== PHASE 1 COMPLETE (All data ready) =========="
    sleep 2
}

# Phase 2: Run inference sequentially with monitoring
phase2_run_sequential() {
    log_success "========== PHASE 2: RUN INFERENCE (Sequential - GPU Safe) =========="
    log_info "Running inference for ${#TASKS[@]} tasks sequentially to avoid GPU OOM..."
    
    for TASK in "${TASKS[@]}"; do
        log_info "------- TASK: $TASK (Inference) -------"
        monitor_gpu "$TASK"
        
        log_info "[$TASK] Starting inference for all T×p combinations..."
        local run_count=0
        for T in "${T_VALUES[@]}"; do
            for P in "${P_VALUES[@]}"; do
                P_CLEAN=${P//./}
                LOGDIR="logs/fig3/$TASK/T${T}_p${P_CLEAN}"
                
                log_info "[$TASK] Running T=$T p=$P inference..."
                python scripts/example/run_one_task.py \
                    --task "$TASK" --model "$MODEL" \
                    --N "$N" --T "$T" --p "$P" \
                    --num_seed "$NUM_SEED" --k "$K" \
                    --log_dir "$LOGDIR" -t run 2>&1 | tee -a "$MASTER_LOG"
                
                ((run_count++))
            done
        done
        log_success "[$TASK] Inference complete (9 configs executed)"
        
        log_info "Sleeping 5s before next task to clear GPU memory..."
        sleep 5
    done
    
    log_success "========== PHASE 2 COMPLETE (All inference done) =========="
    sleep 2
}

# Phase 3: Evaluate all tasks (can run in parallel - minor GPU usage)
phase3_eval_parallel() {
    log_success "========== PHASE 3: EVALUATE (Parallel - Safe) =========="
    log_info "Evaluating all ${#TASKS[@]} tasks (CPU-bound, can parallelize)..."
    
    local pids=()
    for TASK in "${TASKS[@]}"; do
        (
            log_info "[$TASK] Starting evaluation for all T×p combinations..."
            local eval_count=0
            for T in "${T_VALUES[@]}"; do
                for P in "${P_VALUES[@]}"; do
                    P_CLEAN=${P//./}
                    LOGDIR="logs/fig3/$TASK/T${T}_p${P_CLEAN}"
                    
                    python scripts/example/run_one_task.py \
                        --task "$TASK" --model "$MODEL" \
                        --N "$N" --T "$T" --p "$P" \
                        --num_seed "$NUM_SEED" --k "$K" \
                        --log_dir "$LOGDIR" -t eval 2>&1 >/dev/null
                    
                    ((eval_count++))
                    log_info "[$TASK] Evaluated T=$T p=$P ($eval_count/9)"
                done
            done
            log_success "[$TASK] Evaluation complete (9 configs)"
        ) &
        pids+=($!)
    done
    
    log_info "Waiting for all ${#pids[@]} evaluation tasks to complete..."
    for pid in "${pids[@]}"; do
        wait "$pid" || log_warning "Evaluation task (PID $pid) exited with error"
    done
    
    log_success "========== PHASE 3 COMPLETE (All evaluation done) =========="
    sleep 2
}

# Phase 4: Summary and accuracy check
phase4_summary() {
    log_success "========== PHASE 4: ACCURACY SUMMARY =========="
    
    echo "" | tee -a "$ACCURACY_LOG"
    log_info "Task Accuracy Report:"
    echo "TASK,ACCURACY,FAIL_RATE,STATUS" | tee -a "$ACCURACY_LOG"
    
    local total_acc=0
    local healthy_tasks=0
    
    for TASK in "${TASKS[@]}"; do
        ACC=$(check_accuracy "$TASK" 2>/dev/null || echo "ERROR")
        FAIL=$(check_fail_rate "$TASK" 2>/dev/null || echo "ERROR")
        
        if [[ "$ACC" == "ERROR" ]]; then
            log_error "[$TASK] Results unavailable"
            echo "$TASK,ERROR,ERROR,❌ FAILED" | tee -a "$ACCURACY_LOG"
        else
            local acc_percent=$(echo "scale=1; $ACC * 100" | bc)
            local fail_percent=$(echo "scale=1; $FAIL * 100" | bc)
            
            if (( $(echo "$ACC < 0.2" | bc -l) )); then
                log_error "[$TASK] VERY LOW accuracy ($acc_percent%)"
                echo "$TASK,$acc_percent%,$fail_percent%,❌ VERY LOW" | tee -a "$ACCURACY_LOG"
            elif (( $(echo "$ACC < 0.5" | bc -l) )); then
                log_warning "[$TASK] Low accuracy ($acc_percent%)"
                echo "$TASK,$acc_percent%,$fail_percent%,⚠️  LOW" | tee -a "$ACCURACY_LOG"
            elif (( $(echo "$ACC < 0.7" | bc -l) )); then
                log_success "[$TASK] Fair accuracy ($acc_percent%)"
                echo "$TASK,$acc_percent%,$fail_percent%,✅ FAIR" | tee -a "$ACCURACY_LOG"
            else
                log_success "[$TASK] Good accuracy ($acc_percent%)"
                echo "$TASK,$acc_percent%,$fail_percent%,✅ GOOD" | tee -a "$ACCURACY_LOG"
            fi
            
            total_acc=$(echo "$total_acc + $ACC" | bc)
            ((healthy_tasks++))
        fi
    done
    
    if [[ $healthy_tasks -gt 0 ]]; then
        local avg_acc=$(echo "scale=4; $total_acc / $healthy_tasks" | bc)
        local avg_percent=$(echo "scale=1; $avg_acc * 100" | bc)
        log_info "Average Accuracy: $avg_percent%"
        echo "" | tee -a "$ACCURACY_LOG"
        echo "AVERAGE_ACCURACY: $avg_percent%" | tee -a "$ACCURACY_LOG"
    fi
    
    log_success "========== PHASE 4 COMPLETE (Summary generated) =========="
}

# Debugging function to check specific task results
debug_task() {
    local task=$1
    log_info "Debugging task: $task"
    
    local result_file="logs/fig3/$task/results_${MODEL}.json"
    if [[ -f "$result_file" ]]; then
        log_info "Contents of $result_file:"
        python3 -m json.tool "$result_file" | head -50 | tee -a "$MASTER_LOG"
    else
        log_error "Results file not found"
    fi
}

# Main execution
main() {
    log_success "╔════════════════════════════════════════════════════════╗"
    log_success "║     LLM4DyG FIG3 - OPTIMIZED PARALLEL EXECUTION       ║"
    log_success "║           (Shared GPU Safe - Vicuna 7B)                ║"
    log_success "╚════════════════════════════════════════════════════════╝"
    
    check_gpu
    
    log_info "Configuration:"
    log_info "  Model: $MODEL"
    log_info "  Tasks: ${#TASKS[@]} (${TASKS[*]})"
    log_info "  Num Seeds: $NUM_SEED"
    log_info "  T values: ${T_VALUES[*]}"
    log_info "  P values: ${P_VALUES[*]}"
    log_info "  Total configs per task: $((${#T_VALUES[@]} * ${#P_VALUES[@]}))"
    echo ""
    
    log_success "Starting at $(date)"
    
    phase1_gen_all
    phase2_run_sequential
    phase3_eval_parallel
    phase4_summary
    
    log_success "╔════════════════════════════════════════════════════════╗"
    log_success "║            ✅ ALL PHASES COMPLETE                      ║"
    log_success "╚════════════════════════════════════════════════════════╝"
    
    log_info "Results locations:"
    log_info "  Task results: logs/fig3/*/results_${MODEL}.json"
    log_info "  Master log: $MASTER_LOG"
    log_info "  Accuracy log: $ACCURACY_LOG"
    log_info "  Individual logs: logs/fig3/*/T*_p*/run_one_task/*/answer_*.json"
    
    log_success "Complete at $(date)"
}

# Handle interrupt
trap 'log_error "Script interrupted!"; exit 130' INT TERM

main "$@"
