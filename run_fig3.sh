#!/bin/bash

MODEL="llama2-7b"
N=10

# Create a unique timestamp for this entire experiment
RUN_ID=$(date +"%Y%m%d_%H%M%S")

TASKS=(
  when_link
  when_connect
  when_tclosure
  what_node
  which_neighbor
  check_tclosure
  check_tpath
  find_tpath
  sort_edge
)

T_VALUES=(10 20 30)
P_VALUES=(0.3 0.5 0.7)

for TASK in "${TASKS[@]}"
do
  echo "==============================="
  echo "Starting TASK: $TASK"
  echo "==============================="

  for T in "${T_VALUES[@]}"
  do
    for P in "${P_VALUES[@]}"
    do

      # Unique folder per experiment
      LOGDIR="logs/fig3/${RUN_ID}/${TASK}/T${T}_p${P//./}"

      echo ""
      echo "-----------------------------------"
      echo "TASK=$TASK  T=$T  p=$P"
      echo "LOGDIR=$LOGDIR"
      echo "-----------------------------------"
      echo ""

      python scripts/example/run_one_task.py \
        --task $TASK \
        --model $MODEL \
        --N $N \
        --T $T \
        --p $P \
        --log_dir $LOGDIR \
        -t gen

      python scripts/example/run_one_task.py \
        --task $TASK \
        --model $MODEL \
        --N $N \
        --T $T \
        --p $P \
        --log_dir $LOGDIR \
        -t run

      python scripts/example/run_one_task.py \
        --task $TASK \
        --model $MODEL \
        --N $N \
        --T $T \
        --p $P \
        --log_dir $LOGDIR \
        -t eval

    done
  done
done

echo ""
echo "======================================="
echo "ALL TASKS COMPLETED"
echo "Results stored under logs/fig3/$RUN_ID"
echo "======================================="