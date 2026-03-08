#!/bin/bash
# Run when_tclosure, neighbor_at_time, neighbor_in_periods in parallel
# Each task runs gen → run → eval for all T×p combos sequentially,
# but the 3 tasks run in parallel with each other.

MODEL="vicuna-7b"
N=10
NUM_SEED=100
K=2

TASKS=("when_tclosure" "neighbor_at_time" "neighbor_in_periods")
T_VALUES=(10 20 30)
P_VALUES=(0.3 0.5 0.7)

run_task() {
    local TASK=$1
    echo "[$(date +%H:%M:%S)] Starting task: $TASK"

    for T in "${T_VALUES[@]}"; do
        for P in "${P_VALUES[@]}"; do
            # Create log dir name: T10_p03, T20_p05, etc.
            P_CLEAN=${P//./}
            LOGDIR="logs/fig3/${TASK}/T${T}_p${P_CLEAN}"

            echo "[$(date +%H:%M:%S)] [$TASK] T=$T p=$P → $LOGDIR"

            # Step 1: Generate data
            python scripts/example/run_one_task.py \
                --task "$TASK" --model "$MODEL" \
                --N "$N" --T "$T" --p "$P" \
                --num_seed "$NUM_SEED" --k "$K" \
                --log_dir "$LOGDIR" -t gen

            # Step 2: Run model
            python scripts/example/run_one_task.py \
                --task "$TASK" --model "$MODEL" \
                --N "$N" --T "$T" --p "$P" \
                --num_seed "$NUM_SEED" --k "$K" \
                --log_dir "$LOGDIR" -t run

            # Step 3: Evaluate
            python scripts/example/run_one_task.py \
                --task "$TASK" --model "$MODEL" \
                --N "$N" --T "$T" --p "$P" \
                --num_seed "$NUM_SEED" --k "$K" \
                --log_dir "$LOGDIR" -t eval

        done
    done

    echo "[$(date +%H:%M:%S)] ✅ DONE: $TASK"
}

# Run all 3 tasks in parallel
for TASK in "${TASKS[@]}"; do
    run_task "$TASK" &
done

echo ""
echo "=== All 3 tasks launched in parallel ==="
echo "Tasks: ${TASKS[*]}"
echo "Monitor with: tail -f /tmp/task_*.log"
echo ""

# Wait for all background jobs to finish
wait

echo ""
echo "======================================="
echo "ALL 3 TASKS COMPLETED"
echo "======================================="
