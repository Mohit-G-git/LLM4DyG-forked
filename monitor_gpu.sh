#!/bin/bash
# GPU Monitor for LLM4DyG Execution
# Monitors GPU usage and logs memory/utilization in real-time
# Usage: bash monitor_gpu.sh > gpu_monitor.log &

if ! command -v nvidia-smi &> /dev/null; then
    echo "nvidia-smi not found. GPU monitoring not available."
    exit 1
fi

# Create monitoring interval (in seconds)
INTERVAL=5

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}GPU Monitoring Started at $(date)${NC}"
echo ""
echo "Logging GPU metrics every ${INTERVAL}s..."
echo ""

# Log header
echo "TIMESTAMP | GPU | MEMORY_USED (MB) | MEMORY_FREE (MB) | MEMORY_TOTAL (MB) | GPU_UTIL (%) | TEMP (C)"
echo "-----------------------------------------------------------------------------------------------------------"

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get GPU count
    gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader | head -1)
    
    # Iterate through all GPUs
    for ((i=0; i<gpu_count; i++)); do
        gpu_data=$(nvidia-smi -i $i --query-gpu=memory.used,memory.free,memory.total,utilization.gpu,temperature.gpu --format=csv,noheader,nounits)
        
        mem_used=$(echo "$gpu_data" | awk '{print $1}')
        mem_free=$(echo "$gpu_data" | awk '{print $2}')
        mem_total=$(echo "$gpu_data" | awk '{print $3}')
        gpu_util=$(echo "$gpu_data" | awk '{print $4}')
        temp=$(echo "$gpu_data" | awk '{print $5}')
        
        # Color based on memory usage percentage
        mem_pct=$(echo "scale=1; $mem_used / $mem_total * 100" | bc)
        
        if (( $(echo "$mem_pct > 90" | bc -l) )); then
            color=$RED
            warn="⚠️  HIGH"
        elif (( $(echo "$mem_pct > 70" | bc -l) )); then
            color=$YELLOW
            warn="MODERATE"
        else
            color=$GREEN
            warn="OK"
        fi
        
        printf "${color}%s | GPU%d | %14d | %15d | %17d | %11.1f | %7.1f${NC} %s\n" \
            "$timestamp" "$i" "$mem_used" "$mem_free" "$mem_total" "$gpu_util" "$temp" "$warn"
    done
    
    sleep "$INTERVAL"
done
