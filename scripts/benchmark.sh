#!/bin/bash
# Benchmark script for mac-menu cold-start time
# Measures time from process launch to window visible

set -e

BINARY="${1:-.build/mac-menu}"
ITERATIONS="${2:-5}"

if [ ! -x "$BINARY" ]; then
    echo "Error: Binary not found or not executable: $BINARY"
    echo "Run 'make build' first"
    exit 1
fi

# Generate test input (100 items for small input test)
TEST_INPUT=$(seq 1 100 | while read n; do echo "Item $n - Test item for benchmarking"; done)

echo "=== mac-menu Cold Start Benchmark ==="
echo "Binary: $BINARY"
echo "Binary size: $(ls -lh "$BINARY" | awk '{print $5}')"
echo "Iterations: $ITERATIONS"
echo "Test input: 100 lines"
echo ""

declare -a TIMES

for i in $(seq 1 $ITERATIONS); do
    # Kill any existing instances
    pkill -9 mac-menu 2>/dev/null || true
    sleep 0.1

    # Record start time (nanoseconds)
    START=$(python3 -c 'import time; print(time.time_ns())')

    # Launch app with test input in background
    echo "$TEST_INPUT" | "$BINARY" &
    PID=$!

    # Poll for window visibility (timeout after 5 seconds)
    TIMEOUT=50  # 50 * 0.1s = 5 seconds
    COUNTER=0
    while [ $COUNTER -lt $TIMEOUT ]; do
        if osascript -e 'tell application "System Events" to exists window 1 of process "mac-menu"' 2>/dev/null | grep -q true; then
            break
        fi
        sleep 0.1
        COUNTER=$((COUNTER + 1))
    done

    # Record end time
    END=$(python3 -c 'import time; print(time.time_ns())')

    # Calculate elapsed time in milliseconds
    ELAPSED_MS=$(python3 -c "print(($END - $START) / 1000000)")

    # Clean up
    kill $PID 2>/dev/null || true

    if [ $COUNTER -ge $TIMEOUT ]; then
        echo "Run $i: TIMEOUT (window not visible after 5s)"
    else
        echo "Run $i: ${ELAPSED_MS}ms"
        TIMES+=("$ELAPSED_MS")
    fi

    sleep 0.2
done

echo ""
echo "=== Summary ==="
if [ ${#TIMES[@]} -gt 0 ]; then
    # Calculate statistics with Python
    TIMES_CSV=$(IFS=,; echo "${TIMES[*]}")
    python3 << EOF
import statistics
times = [$TIMES_CSV]
if times:
    print(f"Samples: {len(times)}")
    print(f"Min: {min(times):.2f}ms")
    print(f"Max: {max(times):.2f}ms")
    print(f"Mean: {statistics.mean(times):.2f}ms")
    if len(times) > 1:
        print(f"Median: {statistics.median(times):.2f}ms")
        print(f"Std Dev: {statistics.stdev(times):.2f}ms")
EOF
else
    echo "No successful measurements"
fi
