# LLM4DyG Fig3 Parallel Execution Guide

## 🎯 Overview

This guide implements **optimized parallel execution** for LLM4DyG Fig3 heatmap tasks using Vicuna 7B, specifically designed for **shared GPU environments** to avoid the 0% accuracy issue that occurred with naive parallelization.

## 📊 Tasks Implemented

All 9 Fig3 tasks are fully implemented in your codebase:

| Code Name | Paper Name | Status |
|-----------|-----------|--------|
| `when_link` | When Link | ✅ Ready |
| `when_connect` | When Connect | ✅ Ready |
| `when_tclosure` | When T-closure | ✅ Ready |
| `what_node` | Neighbor At Time | ✅ Ready |
| `which_neighbor` | Neighbor In Periods | ✅ Ready |
| `check_tclosure` | Check T-closure | ✅ Ready |
| `check_tpath` | Check T-path | ✅ Ready |
| `find_tpath` | Find T-path | ✅ Ready |
| `sort_edge` | Sort Edge | ✅ Ready |

## ⚡ Why Previous Attempts Failed (0% Accuracy)

### Root Causes:
1. **GPU Memory Thrashing**: Running multiple inference tasks in parallel on shared GPU → OOM/slowdowns
2. **Token Rate Limiting**: `TPMController` enforces token budgets; parallel tasks bypass this
3. **Response Timeout/Truncation**: Long-running queries on shared GPU → incomplete responses → parsing failures
4. **Batch Sequence Issues**: Running gen + run + eval all in parallel → GPU catastrophe
5. **Response Parsing Failures**: Truncated/malformed responses don't match regex patterns → error code -1 → averaged to 0%

### The Fix:
- **Phase 1** (gen): Parallel across all tasks ✅ (CPU-bound)
- **Phase 2** (run): Sequential across tasks ✅ (GPU-bound, prevents contention)
- **Phase 3** (eval): Parallel across all tasks ✅ (CPU-bound)
- **Phase 4** (monitor): Check accuracy after each task immediately

## 📦 Scripts Provided

### 1. **Main Execution Script** - `run_fig3_parallel_safe.sh`

**Most important script. Use this to run everything.**

```bash
bash run_fig3_parallel_safe.sh
```

**What it does:**
- Phase 1: Generates data for all 9 tasks in parallel (safe, CPU-only)
- Phase 2: Runs inference sequentially per task (GPU-safe)
- Phase 3: Evaluates all tasks in parallel (CPU-only)
- Phase 4: Reports accuracy and identifies issues

**Features:**
- Color-coded logging with timestamps
- GPU health checks before/during execution
- Automatic accuracy verification after each task
- Detailed success/failure reporting
- Master log file for all output

**Output:**
- `logs/run_parallel_safe/master_TIMESTAMP.log` - Complete execution log
- `logs/run_parallel_safe/accuracy_TIMESTAMP.log` - Final accuracy report
- `logs/fig3/{task}/results_{model}.json` - Per-task detailed results

---

### 2. **Quick Accuracy Checker** - `check_accuracy.sh`

**Use this anytime to see current accuracy status.**

```bash
bash check_accuracy.sh
```

**Output:**
```
TASK              | ACCURACY     | FAIL_RATE    | STATUS
-————————————————————————————————————————————————————————
when_link         | 85.2%        | 5.0%         | ✅ GOOD
when_connect      | 72.1%        | 8.5%         | ✅ FAIR
...
ALL TASKS         | 76.5%        | (avg)        | AVERAGE
```

**Status icons:**
- ✅ GOOD: Accuracy ≥ 70% (Reliable)
- ✅ FAIR: Accuracy 50-70% (Acceptable)  
- ⚠️ LOW: Accuracy 20-50% (Debug needed)
- ❌ VERY LOW: Accuracy < 20% (Major issues)
- ⏳ PENDING: Task not yet evaluated

---

### 3. **GPU Monitor** - `monitor_gpu.sh`

**Run in background to track GPU usage during execution.**

```bash
bash monitor_gpu.sh > gpu_monitor.log &
# ... run main script ...
tail -f gpu_monitor.log
```

**Tracks:**
- Memory usage per GPU
- Memory percentage
- GPU utilization
- Temperature
- Color-coded warnings (Red = >90%, Yellow = >70%)

---

### 4. **Task Debugger** - `debug_task.sh`

**Use when a task has low accuracy to diagnose the problem.**

```bash
bash debug_task.sh when_link
bash debug_task.sh what_node
bash debug_task.sh check_tpath
```

**Diagnostic steps:**
1. ✅ Verify task implementation
2. ✅ Extract accuracy metrics
3. ✅ Analyze parse failures
4. ✅ Show example failures + expected answers
5. ✅ Provide recovery recommendations

**Example output:**
```
⚠️  Found 23 parse errors (metric = -1)
   This means LLM response format doesn't match expected pattern.

Examining first failure: 10_10_0.3_0
  Model Response: "The nodes linked are: [1, 2, 3"  ← Truncated!
  Expected Answer: [1, 2, 3]

Recommendations:
  1. Response parsing is broken
  2. GPU memory issues causing truncated responses
  - Manually check responses
  - Test with smaller NUM_SEED (10-20)
```

---

## 🚀 Usage Instructions

### Recommended Workflow:

#### **Step 1: Start GPU Monitoring (Optional but Useful)**

```bash
# In a separate terminal
bash monitor_gpu.sh > gpu_monitor_$(date +%s).log &
GPM_PID=$!
tail -f gpu_monitor_$(ls -t gpu_monitor_*.log | head -1).log
```

#### **Step 2: Run Main Execution**

```bash
bash run_fig3_parallel_safe.sh
```

**Typical execution time:**
- Phase 1 (gen): 5-10 minutes (parallel, all 9 tasks)
- Phase 2 (run): 30-90 minutes (sequential, depends on GPU speed)
- Phase 3 (eval): 5-10 minutes (parallel)
- **Total: ~1-2 hours**

#### **Step 3: Check Results During Execution**

```bash
# In another terminal, monitor progress
while true; do
  clear
  bash check_accuracy.sh
  sleep 30  # refresh every 30s
done
```

#### **Step 4: Debug Any Low-Accuracy Tasks**

```bash
# If accuracy < 50% for a task
bash debug_task.sh when_link
bash debug_task.sh what_node
bash debug_task.sh find_tpath
```

---

## ⚙️ Configuration

### Adjust Settings in `run_fig3_parallel_safe.sh`:

```bash
MODEL="vicuna-7b"           # Model name
N=10                        # Number of nodes
NUM_SEED=100                # Number of problem instances (start with 10-20 for testing)
K=2                         # Number of few-shot examples
T_VALUES=(10 20 30)         # Time steps
P_VALUES=(0.3 0.5 0.7)      # Edge probabilities
```

**For debugging/testing (fast iteration):**
```bash
NUM_SEED=10    # Instead of 100 (10x faster)
MODEL="vicuna-7b"
```

**For final benchmark (accurate results):**
```bash
NUM_SEED=100   # Full dataset
MODEL="vicuna-7b"
```

---

## 🔍 Interpreting Results

### Expected Accuracy Ranges:

| Task | Expected Accuracy | Notes |
|------|------------------|-------|
| when_link | 60-85% | Straightforward temporal edge query |
| when_connect | 55-80% | Similar to when_link |
| when_tclosure | 40-70% | More complex transitivity |
| what_node | 50-75% | Neighbor identification |
| which_neighbor | 45-70% | Requires temporal logic |
| check_tclosure | 50-75% | Boolean yes/no task |
| check_tpath | 45-65% | Path validation, complex |
| find_tpath | 40-60% | Path finding, most difficult |
| sort_edge | 80-95% | Simple sorting task |

**Overall benchmark target: 60-70% average accuracy**

### Debug Checklist if Accuracy < 20%:

- [ ] Check `fail_rate` in results JSON
  - If > 0.3: Response parsing broken
  - If < 0.1: Accuracy issue, not parsing
  
- [ ] Manually inspect LLM responses:
  ```bash
  cat logs/fig3/{task}/{folder}/answer_{model}.json | jq .content
  ```
  
- [ ] Compare to expected format in evaluate() function:
  ```bash
  grep "def evaluate" llm4dyg/utils/task/{task}.py
  ```
  
- [ ] Check GPU memory during run:
  ```bash
  nvidia-smi  # Should show < 90% used
  ```
  
- [ ] Try with smaller NUM_SEED:
  ```bash
  # Edit run_fig3_parallel_safe.sh
  NUM_SEED=10  # Test with 10 instances first
  ```

---

## 📁 Output Structure

```
logs/
├── run_parallel_safe/
│   ├── master_YYYYMMDD_HHMMSS.log      # Complete execution log
│   └── accuracy_YYYYMMDD_HHMMSS.log    # Final accuracy report
├── fig3/
│   ├── when_link/
│   │   ├── results_vicuna-7b.json      # Accuracy metrics
│   │   ├── T10_p03/
│   │   │   ├── prompt_files.json
│   │   │   ├── 10_10_0.3_0/
│   │   │   │   ├── graph.json          # Generated graph
│   │   │   │   ├── qa.json             # Question & answer
│   │   │   │   ├── prompt_qa.json      # Formatted prompt
│   │   │   │   └── answer_vicuna-7b.json  # LLM response
│   │   │   └── ...
│   │   └── T10_p05/, T10_p07/, T20_p03/, ...
│   ├── when_connect/
│   ├── what_node/
│   └── ... (all 9 tasks)
```

---

## 🛠️ Troubleshooting

### Issue: "GPU out of memory" during Phase 2

**Solution:**
```bash
# In run_fig3_parallel_safe.sh, reduce:
NUM_SEED=50  # instead of 100

# Or modify max tokens in run_one_task command:
--max_tokens 512  # instead of default 2048
```

### Issue: "All responses are truncated"

**Solution:**
- Check if model server is running correctly
- Verify model can return full responses with smaller graphs
- Check `logs/fig3/{task}/{folder}/answer_{model}.json` for truncation

### Issue: "Parsing errors > 30%"

**Solution:**
```bash
# Run debugger to see exact issue
bash debug_task.sh {task_name}

# Manually check first failure
cat logs/fig3/{task_name}/*/answer_vicuna-7b.json | head -50
```

### Issue: "Some tasks not starting"

**Solution:**
```bash
# Check for file conflicts
rm -rf logs/fig3/{task}/results_vicuna-7b.json

# Re-run just that task
python scripts/example/run_one_task.py \
  --task {task_name} --model vicuna-7b \
  --N 10 --T 10 --p 0.3 \
  --num_seed 10 --k 2 \
  --log_dir logs/fig3/{task_name}/T10_p03 -t gen
```

---

## 📈 Performance Tips

1. **Use SSD for logs**: Faster I/O operations
2. **Monitor GPU memory**: Keep under 90% occupied
3. **Reduce NUM_SEED initially**: Start with 10, scale to 100
4. **Use smaller models for testing**: Test on CPU first
5. **Check logs in real-time**: Don't wait until end

---

## 📝 Log Files

- **Master log**: `logs/run_parallel_safe/master_*.log`
  - Contains all commands executed
  - GPU checks
  - Accuracy checks
  
- **GPU monitor**: `gpu_monitor_*.log` (if running)
  - GPU memory timeline
  - Temperature tracking
  - Utilization metrics

- **Accuracy report**: `logs/run_parallel_safe/accuracy_*.log`
  - Final accuracy table
  - Status for each task
  - Average accuracy

---

## 🎓 Understanding the Parallelization

### Why This Pattern Works:

```
┌─ CPU-bound task (can parallelize) ─────────────────────┐
│  - Data generation (gen)        parallelizable          │
│  - Response evaluation (eval)   parallelizable          │
│  - Accuracy checking            parallelizable          │
└──────────────────────────────────────────────────────────┘

┌─ GPU-bound task (MUST sequentialize) ──────────────────┐
│  - Model inference (run)        NOT parallelizable     │
│                                                         │
│  Running multiple in parallel:                          │
│  ❌ OOM (GPU memory exhausted)                          │
│  ❌ Context switching overhead                         │
│  ❌ Token rate limiter confusion                       │
│  ❌ Incomplete responses                               │
└──────────────────────────────────────────────────────────┘
```

### Execution Timeline:

```
Time →

Phase 1 (gen):    Task1  Task2  Task3  Task4  Task5
                  ├─────┤├─────┤├─────┤├─────┤├─────┤
                  └────────────┬────────────────────┘
                         (all parallel, safe)

Phase 2 (run):    Task1  Task2  Task3  Task4  Task5
                  ├──────────┤├──────────┤├──────────┤
                  └───────────┬──────────┬──────────┘
                    (sequential, GPU-safe)

Phase 3 (eval):   Task1  Task2  Task3  Task4  Task5
                  ├────┤├────┤├────┤├────┤├────┤
                  └──────────┬──────────────────┘
                      (all parallel, safe)
```

---

## 📞 Support

If you encounter issues:

1. **Run debugger**: `bash debug_task.sh {problematic_task}`
2. **Check GPU**: `nvidia-smi`
3. **Review logs**: `tail -f logs/run_parallel_safe/master_*.log`
4. **Manually test one task**:
   ```bash
   python scripts/example/run_one_task.py \
     --task when_link --model vicuna-7b -t gen
   python scripts/example/run_one_task.py \
     --task when_link --model vicuna-7b -t run
   python scripts/example/run_one_task.py \
     --task when_link --model vicuna-7b -t eval
   ```

---

**Ready to start? Run:**
```bash
bash run_fig3_parallel_safe.sh
```

Good luck! 🚀
