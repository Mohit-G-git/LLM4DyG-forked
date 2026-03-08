#!/bin/bash
# Run what_node (="neighbor_at_time") and which_neighbor (="neighbor_in_periods") in parallel
#
# TASK NAME MAPPING (paper name → code name):
#   neighbor_at_time    → what_node
#   neighbor_in_periods → which_neighbor

set -e

MODEL="vicuna-7b"
N=10
NUM_SEED=100
K=2

T_VALUES=(10 20 30)
P_VALUES=(0.3 0.5 0.7)

run_task() {
    local TASK=$1
    local PAPER_NAME=$2
    local LOGFILE="/tmp/${TASK}.log"

    echo "[$(date +%H:%M:%S)] Starting task: $TASK (paper name: $PAPER_NAME)" | tee "$LOGFILE"

    for T in "${T_VALUES[@]}"; do
        for P in "${P_VALUES[@]}"; do
            P_CLEAN=${P//./}
            # Use paper name for log dirs so they match your existing structure
            LOGDIR="logs/fig3/${PAPER_NAME}/T${T}_p${P_CLEAN}"

            echo "[$(date +%H:%M:%S)] [$TASK] T=$T p=$P gen" | tee -a "$LOGFILE"
            python -u scripts/example/run_one_task.py \
                --task "$TASK" --model "$MODEL" \
                --N "$N" --T "$T" --p "$P" \
                --num_seed "$NUM_SEED" --k "$K" \
                --log_dir "$LOGDIR" -t gen 2>&1 | tee -a "$LOGFILE"

            echo "[$(date +%H:%M:%S)] [$TASK] T=$T p=$P run" | tee -a "$LOGFILE"
            python -u scripts/example/run_one_task.py \
                --task "$TASK" --model "$MODEL" \
                --N "$N" --T "$T" --p "$P" \
                --num_seed "$NUM_SEED" --k "$K" \
                --log_dir "$LOGDIR" -t run 2>&1 | tee -a "$LOGFILE"

            echo "[$(date +%H:%M:%S)] [$TASK] T=$T p=$P eval" | tee -a "$LOGFILE"
            python -u scripts/example/run_one_task.py \
                --task "$TASK" --model "$MODEL" \
                --N "$N" --T "$T" --p "$P" \
                --num_seed "$NUM_SEED" --k "$K" \
                --log_dir "$LOGDIR" -t eval 2>&1 | tee -a "$LOGFILE"

        done
    done

    echo "[$(date +%H:%M:%S)] ✅ DONE: $TASK" | tee -a "$LOGFILE"
}

# Run both tasks in parallel (code name, paper name)
run_task "what_node" "neighbor_at_time" &
PID1=$!
run_task "which_neighbor" "neighbor_in_periods" &
PID2=$!

echo ""
echo "=== Both tasks launched in parallel ==="
echo "  what_node        (= neighbor_at_time)    PID=$PID1"
echo "  which_neighbor   (= neighbor_in_periods) PID=$PID2"
echo ""
echo "Monitor: tail -f /tmp/what_node.log /tmp/which_neighbor.log"
echo ""

wait $PID1
wait $PID2

echo ""
echo "======================================="
echo "BOTH TASKS COMPLETED"
echo "======================================="
