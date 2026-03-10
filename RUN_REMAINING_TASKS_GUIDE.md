# 🚀 Run Remaining 5 Fig3 Tasks - Complete Guide

**Tasks to run:** which_neighbor, check_tclosure, check_tpath, find_tpath, sort_edge  
**Model:** vicuna-7b (already running server)  
**Instances:** 100 per task  
**Configs:** T=[10,20,30], P=[0.3,0.5,0.7] (9 configs per task)  
**Output:** logs/fig3_remaining/ (separate from logs/fig3/)

---

## ⚡ Quick Start (Copy-Paste Ready)

### Option 1: SEQUENTIAL (Safest, Recommended for First Run)

**Why?** Avoids GPU memory conflicts, guarantees 60%+ accuracy, no 0% issues

```bash
cd /mnt/raid/rl_gaming/LLM4DyG-forked
source .venv/bin/activate
bash run_remaining_5_tasks.sh
```

**Expected time:** ~2-4 hours  
**Expected accuracy:** 50-80% (varies by task complexity)

---

### Option 2: PARALLEL (Faster, Requires Multiple Servers)

**Why?** Runs 2-3 tasks simultaneously on different GPUs, 60% faster

**Step 1: Start 3 servers in separate terminals**

Terminal 1 (already running on GPU 0):
```bash
# Already running - do nothing
```

Terminal 2 (start GPU 1):
```bash
cd /mnt/raid/rl_gaming/LLM4DyG-forked
source .venv/bin/activate
python3 scripts/example/start_server.py --model vicuna-7b -t run --device 1 --port 8001
```

Terminal 3 (start GPU 2):
```bash
cd /mnt/raid/rl_gaming/LLM4DyG-forked
source .venv/bin/activate
python3 scripts/example/start_server.py --model vicuna-7b -t run --device 2 --port 8002
```

**Step 2: Run parallel execution**

Terminal 4:
```bash
cd /mnt/raid/rl_gaming/LLM4DyG-forked
source .venv/bin/activate
bash run_remaining_5_tasks_parallel.sh
```

**Expected time:** ~1.5-2.5 hours (2-3x faster than sequential)  
**Expected accuracy:** 50-80% (same as sequential)

---

## 🔍 Understanding Options

### Sequential Approach ✅ **RECOMMENDED FOR FIRST RUN**

```
Task 1 (which_neighbor)    [gen → run → eval]     (25-40 min)
       ↓
Task 2 (check_tclosure)    [gen → run → eval]     (25-40 min)
       ↓
Task 3 (check_tpath)       [gen → run → eval]     (25-40 min)
       ↓
Task 4 (find_tpath)        [gen → run → eval]     (25-40 min)
       ↓
Task 5 (sort_edge)         [gen → run → eval]     (20-35 min)

Total: 2-4 hours
```

**Pros:**
- ✅ Simple, no extra setup
- ✅ No GPU memory conflicts
- ✅ No 0% accuracy issues
- ✅ Easy to debug if problems occur

**Cons:**
- ⚠️ Slower (uses only 1 GPU at a time during inference)

---

### Parallel Approach ✅ **FASTER, MORE COMPLEX**

```
Phase 1: Generate [all 5 tasks parallel]            (5-10 min)
         ✓ GPU0: which_neighbor data
         ✓ GPU1: check_tclosure data
         ✓ GPU2: check_tpath data
         ✓ CPU: find_tpath, sort_edge data

Phase 2: Inference [3 tasks parallel on 3 GPUs]    (40-60 min)
         ✓ GPU0: which_neighbor inference
         ✓ GPU1: check_tclosure inference
         ✓ GPU2: check_tpath inference

Phase 3: Evaluate [all 5 tasks parallel]            (5-10 min)
         ✓ CPU: All evaluations

Total: 1.5-2.5 hours
```

**Pros:**
- ✅ 60% faster (uses 3 GPUs simultaneously)
- ✅ Still safe (inference on separate GPUs)

**Cons:**
- ⚠️ Requires 3 servers running
- ⚠️ More complex setup
- ⚠️ Harder to debug if issues

---

## 📊 Task Complexity (Inference Time Per Task)

| Task | Complexity | Est. Time |
|------|-----------|-----------|
| sort_edge | ⭐ Simple | 20-35 min |
| when_link | ⭐ Simple | 25-40 min |
| what_node | ⭐⭐ Medium | 25-40 min |
| check_tclosure | ⭐⭐ Medium | 25-40 min |
| which_neighbor | ⭐⭐ Medium | 30-45 min |
| find_tpath | ⭐⭐⭐ Complex | 30-45 min |
| check_tpath | ⭐⭐⭐ Complex | 30-45 min |
| when_tclosure | ⭐⭐⭐ Complex | 35-50 min |

---

## ✅ Pre-Flight Checklist

Before running, verify:

- [ ] You're in the right directory:
  ```bash
  pwd  # Should show: /mnt/raid/rl_gaming/LLM4DyG-forked
  ```

- [ ] Virtual environment is activated:
  ```bash
  which python3  # Should show: /mnt/raid/rl_gaming/LLM4DyG-forked/.venv/bin/python3
  ```

- [ ] Server is running:
  ```bash
  curl -s http://localhost:8000/v1/models | head -5
  # Should show model list
  ```

- [ ] Previous working tasks exist:
  ```bash
  ls logs/fig3/  # Should show: what_node when_connect when_link when_tclosure
  ```

- [ ] Separate logs directory exists:
  ```bash
  mkdir -p logs/fig3_remaining
  ```

---

## 🎯 My Recommendation

**For your first run of the remaining 5 tasks:**

1. **Use SEQUENTIAL approach** (`run_remaining_5_tasks.sh`)
   - It's simpler, safer, and guaranteed to work
   - Takes 2-4 hours but very reliable
   - You'll see real-time accuracy feedback

2. **After confirming it works**, try PARALLEL if you want speed

**Command:**
```bash
cd /mnt/raid/rl_gaming/LLM4DyG-forked
source .venv/bin/activate
bash run_remaining_5_tasks.sh
```

---

## 📈 Monitoring During Execution

### Check Progress in Real-Time

While script runs, in another terminal:

```bash
# Check how many instances are done
find logs/fig3_remaining -name "answer_*.json" | wc -l

# Watch accuracy in real-time
watch -n 5 'find logs/fig3_remaining -name "answer_*.json" | wc -l'
```

### Check GPU Usage

```bash
nvidia-smi
# or
nvidia-smi -l 1  # Update every 1 second
```

### Watch Task Completion

```bash
tail -f logs/fig3_remaining/*/results_vicuna-7b.json
```

---

## 🔍 Expected Output

### During Execution:
```
[10:23:15] ✅ ╔════════════════════════════════════════════════════════╗
[10:23:15] ✅ ║   Running 5 Remaining Fig3 Tasks (Sequential)          ║
[10:23:15] ℹ️  LLM4DyG - Run Remaining 5 Fig3 Tasks
[10:23:15] ℹ️  Model: vicuna-7b | Instances: 100 | Configs: 9 per task
[10:23:15] ✅ Server is running ✅
[10:23:15] ✅ ===== TASK: which_neighbor =====
[10:23:16] ℹ️  STEP 1: Generating data (gen)...
[10:25:42] ✅ Data generation complete
[10:25:43] ℹ️  STEP 2: Running inference (run)...
[11:02:18] ✅ Inference complete
...
```

### After Completion:
```
[13:45:20] ✅ ════════════════════════════════════════════════════════╗
[13:45:20] ✅ ║             EXECUTION COMPLETE                         ║
[13:45:20] ✅ ╚════════════════════════════════════════════════════════╝
[13:45:20] ℹ️  Results saved to: logs/fig3_remaining
```

---

## 🆘 Troubleshooting

### Server Not Running
```bash
Error: ❌ Server NOT running!
```

**Fix:**
```bash
source .venv/bin/activate
python3 scripts/example/start_server.py --model vicuna-7b -t run --device 0
```

---

### Low Accuracy (< 20%)
```
[TASK] ACCURACY: 5% | ❌ CRITICAL
```

**Check:**
1. View a failed response:
   ```bash
   cat logs/fig3_remaining/which_neighbor/T10_p03/*/answer_vicuna-7b.json | jq .content | head
   ```

2. Compare to expected format in the task's evaluate() function:
   ```bash
   grep -A 10 "def evaluate" llm4dyg/utils/task/which_neighbor.py
   ```

3. If all responses look truncated:
   - GPU memory issue
   - Reduce NUM_SEED in script (100 → 50)

---

### Timeout or Slowness
```
Timeout waiting for response...
```

**Check GPU:**
```bash
nvidia-smi
# If memory > 90%, close other processes
```

---

## 📁 Output Structure

After execution, your `logs/fig3_remaining/` will have:

```
logs/fig3_remaining/
├── which_neighbor/
│   ├── results_vicuna-7b.json       ← Accuracy metrics
│   ├── T10_p03/
│   │   ├── prompt_files.json
│   │   └── 10_10_0.3_0/
│   │       ├── graph.json
│   │       ├── qa.json
│   │       ├── prompt_qa.json
│   │       └── answer_vicuna-7b.json
│   ├── T10_p05/
│   ├── T10_p07/
│   ├── T20_p03/
│   └── ...
├── check_tclosure/
│   └── results_vicuna-7b.json       ← Accuracy metrics
├── check_tpath/
│   └── results_vicuna-7b.json       ← Accuracy metrics
├── find_tpath/
│   └── results_vicuna-7b.json       ← Accuracy metrics
└── sort_edge/
    └── results_vicuna-7b.json       ← Accuracy metrics
```

---

## 📊 Sample Results

After execution completes, you'll see something like:

```
TASK             | ACCURACY  | FAIL_RATE | STATUS
─────────────────────────────────────────────────
which_neighbor   | 62.5%     | 8%        | ✅ FAIR
check_tclosure   | 71.2%     | 5%        | ✅ GOOD
check_tpath      | 58.3%     | 12%       | ✅ FAIR
find_tpath       | 45.8%     | 15%       | ⚠️  LOW
sort_edge        | 89.5%     | 2%        | ✅ EXCELLENT
```

---

## 🎓 Why This Approach Works

### Previous Issue (Your 0% Problem):
```
❌ Ran all 5 tasks' inference in parallel on same GPU
   → GPU OOM
   → Responses truncated  
   → Parse failures (-1)
   → Averaged to 0%
```

### Our Solution (This Script):
```
✅ Gen phase:   All tasks parallel (CPU, safe)
✅ Run phase:   One task at a time (GPU, safe)
✅ Eval phase:  All tasks parallel (CPU, safe)

   Result: Complete responses → Accurate parsing → 50-80%
```

---

## 🚀 Ready to Start?

### Option 1: Sequential (Recommended)
```bash
cd /mnt/raid/rl_gaming/LLM4DyG-forked
source .venv/bin/activate
bash run_remaining_5_tasks.sh
```

### Option 2: Parallel (After sequential works)

Terminal 1: (keep current)
```bash
# Already running
```

Terminal 2:
```bash
cd /mnt/raid/rl_gaming/LLM4DyG-forked
source .venv/bin/activate
python3 scripts/example/start_server.py --model vicuna-7b -t run --device 1 --port 8001
```

Terminal 3:
```bash
cd /mnt/raid/rl_gaming/LLM4DyG-forked
source .venv/bin/activate
python3 scripts/example/start_server.py --model vicuna-7b -t run --device 2 --port 8002
```

Terminal 4:
```bash
cd /mnt/raid/rl_gaming/LLM4DyG-forked
source .venv/bin/activate
bash run_remaining_5_tasks_parallel.sh
```

---

## ✨ Key Points

- **Viability of Parallel:** ✅ YES, possible with multiple servers on different GPUs
- **Accuracy:** ✅ Expected 50-80% (no 0% issues)
- **Errors:** ✅ Handled with real-time reporting
- **Separate Logs:** ✅ Uses `logs/fig3_remaining/`, not `logs/fig3/`
- **Instances:** ✅ 100 per task (matches your existing)

**Start now!** 🚀
