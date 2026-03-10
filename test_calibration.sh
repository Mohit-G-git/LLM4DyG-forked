#!/bin/bash
# Calibration script to test CoT adjustments on 5 seeds for the 5 remaining tasks

set -e

TASKS=("which_neighbor" "check_tclosure" "check_tpath" "find_tpath" "sort_edge")

for TASK in "${TASKS[@]}"; do
    echo "========================================="
    echo "Running Calibration for Task: $TASK"
    echo "========================================="
    
    LOGDIR="logs/calibration/${TASK}"
    
    # Clean old logs if they exist
    rm -rf "$LOGDIR"
    
    # 1. Gen
    conda run -n llm4dyg python scripts/example/run_one_task.py \
        --task "$TASK" --model vicuna-7b --N 10 --T 10 --p 0.3 \
        --num_seed 5 --k 2 --add_cot 1 --add_role 1 \
        --log_dir "$LOGDIR" -t gen
        
    # 2. Run
    conda run -n llm4dyg python scripts/example/run_one_task.py \
        --task "$TASK" --model vicuna-7b --N 10 --T 10 --p 0.3 \
        --num_seed 5 --k 2 --add_cot 1 --add_role 1 \
        --log_dir "$LOGDIR" -t run
        
    # 3. Eval
    conda run -n llm4dyg python scripts/example/run_one_task.py \
        --task "$TASK" --model vicuna-7b --N 10 --T 10 --p 0.3 \
        --num_seed 5 --k 2 --add_cot 1 --add_role 1 \
        --log_dir "$LOGDIR" -t eval
done

echo "Calibration complete! Check logs/calibration/*/run_one_task/*/results_vicuna-7b.json for accuracies."
