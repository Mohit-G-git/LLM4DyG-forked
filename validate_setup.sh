#!/bin/bash
# Quick Validation Script for LLM4DyG Setup
# Runs a single small test to verify everything works before benchmark
# Usage: bash validate_setup.sh

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        LLM4DyG Setup Validation (Quick Test)          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration
MODEL="vicuna-7b"
TEST_TASK="when_link"
TEST_DIR="logs/validation/test_$$"

cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up test files...${NC}"
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

echo -e "${YELLOW}Configuration:${NC}"
echo "  Model: $MODEL"
echo "  Test Task: $TEST_TASK"
echo "  Test Dir: $TEST_DIR"
echo ""

# Step 1: Check environment
echo -e "${YELLOW}Step 1: Checking environment...${NC}"

if command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version 2>&1)
    echo -e "  ${GREEN}✅${NC} Python: $PYTHON_VERSION"
else
    echo -e "  ${RED}❌${NC} Python not found"
    exit 1
fi

if command -v pip &> /dev/null; then
    echo -e "  ${GREEN}✅${NC} Pip found"
else
    echo -e "  ${RED}❌${NC} Pip not found"
    exit 1
fi

# Step 2: Check required packages
echo ""
echo -e "${YELLOW}Step 2: Checking Python packages...${NC}"

packages=("llm4dyg" "numpy" "pandas" "torch")
for pkg in "${packages[@]}"; do
    python -c "import $pkg" 2>/dev/null && \
        echo -e "  ${GREEN}✅${NC} $pkg" || \
        echo -e "  ${RED}❌${NC} $pkg (missing)"
done

# Step 3: Check GPU
echo ""
echo -e "${YELLOW}Step 3: Checking GPU...${NC}"

if command -v nvidia-smi &> /dev/null; then
    GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
    echo -e "  ${GREEN}✅${NC} Found $GPU_COUNT GPU(s)"
    
    # Check memory
    MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -1)
    echo -e "  ${GREEN}✅${NC} GPU Memory: ${MEM} MB"
else
    echo -e "  ${YELLOW}⚠️${NC} nvidia-smi not found (will try CPU)"
fi

# Step 4: Test task file
echo ""
echo -e "${YELLOW}Step 4: Checking task files...${NC}"

if [[ -f "llm4dyg/utils/task/${TEST_TASK}.py" ]]; then
    echo -e "  ${GREEN}✅${NC} Task file exists: llm4dyg/utils/task/${TEST_TASK}.py"
    
    # Check methods
    grep -q "def generate_qa" "llm4dyg/utils/task/${TEST_TASK}.py" && \
        echo -e "    ${GREEN}✅${NC} generate_qa method" || \
        echo -e "    ${RED}❌${NC} generate_qa missing"
    
    grep -q "def evaluate" "llm4dyg/utils/task/${TEST_TASK}.py" && \
        echo -e "    ${GREEN}✅${NC} evaluate method" || \
        echo -e "    ${RED}❌${NC} evaluate missing"
else
    echo -e "  ${RED}❌${NC} Task file not found"
    exit 1
fi

# Step 5: Run mini test
echo ""
echo -e "${YELLOW}Step 5: Running mini test (10 instances)...${NC}"

mkdir -p "$TEST_DIR"

echo -e "  ${BLUE}→${NC} Generating data..."
python scripts/example/run_one_task.py \
    --task "$TEST_TASK" --model "$MODEL" \
    --N 5 --T 5 --p 0.5 \
    --num_seed 5 --k 1 \
    --log_dir "$TEST_DIR/gen" -t gen 2>&1 | grep -E "generate|ERROR" || true

if [[ -f "$TEST_DIR/gen/prompt_files.json" ]]; then
    echo -e "  ${GREEN}✅${NC} Data generated"
else
    echo -e "  ${RED}❌${NC} Data generation failed"
    exit 1
fi

echo -e "  ${BLUE}→${NC} Running inference (this may take 1-5 minutes)..."
timeout 300 python scripts/example/run_one_task.py \
    --task "$TEST_TASK" --model "$MODEL" \
    --N 5 --T 5 --p 0.5 \
    --num_seed 5 --k 1 \
    --log_dir "$TEST_DIR/run" -t run 2>&1 | tail -20 || {
    if [[ $? -eq 124 ]]; then
        echo -e "  ${RED}❌${NC} Inference timeout (>5 min, model server may be slow)"
    else
        echo -e "  ${RED}❌${NC} Inference failed"
    fi
    exit 1
}

if ls "$TEST_DIR/run"/*/answer_*.json 1> /dev/null 2>&1; then
    echo -e "  ${GREEN}✅${NC} Inference completed"
else
    echo -e "  ${RED}❌${NC} No answers generated"
    exit 1
fi

echo -e "  ${BLUE}→${NC} Evaluating results..."
python scripts/example/run_one_task.py \
    --task "$TEST_TASK" --model "$MODEL" \
    --N 5 --T 5 --p 0.5 \
    --num_seed 5 --k 1 \
    --log_dir "$TEST_DIR/eval" -t eval 2>&1 | tail -10 || true

if [[ -f "$TEST_DIR/eval/results_${MODEL}.json" ]]; then
    echo -e "  ${GREEN}✅${NC} Evaluation completed"
    
    # Show results
    python3 << 'EOF'
import json
import sys

result_file = sys.argv[1]
with open(result_file, 'r') as f:
    data = json.load(f)

acc = data.get('average_acc', 0)
fail = data.get('fail_rate', 0)

print(f"\n  Results:")
print(f"    Accuracy: {acc:.2%}")
print(f"    Fail Rate: {fail:.2%}")
print(f"    Instances: {len(data.get('metrics', []))}")
print(f"    Tokens: {data.get('average_tokens', 0):.0f}")

if acc < 0.2:
    print("\n    ⚠️  Low accuracy - may indicate issues")
elif acc < 0.5:
    print("\n    ℹ️  Fair accuracy - acceptable for testing")
else:
    print("\n    ✅ Good accuracy - setup working!")
EOF
    "$TEST_DIR/eval/results_${MODEL}.json" || true
else
    echo -e "  ${RED}❌${NC} Evaluation failed"
    exit 1
fi

# Step 6: Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Validation Complete!                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✅ Your setup is ready to run the full benchmark!${NC}"
echo ""
echo "Next steps:"
echo "  1. Optionally start GPU monitoring in a separate terminal:"
echo "     ${YELLOW}bash monitor_gpu.sh > gpu_monitor_\$(date +%s).log &${NC}"
echo ""
echo "  2. Run the full benchmark:"
echo "     ${YELLOW}bash run_fig3_parallel_safe.sh${NC}"
echo ""
echo "  3. Monitor progress in another terminal:"
echo "     ${YELLOW}bash check_accuracy.sh${NC}"
echo ""
