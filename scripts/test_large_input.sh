#!/bin/bash
# Test with larger input to see if async loading helps

BINARY=".build/mac-menu"
SIZE=${1:-10000}

echo "=== Testing with $SIZE lines ==="

# Generate input
INPUT=$(seq 1 $SIZE)

for i in 1 2 3; do
    pkill -9 mac-menu 2>/dev/null
    sleep 0.1

    START=$(python3 -c 'import time; print(time.time_ns())')
    echo "$INPUT" | timeout 5 "$BINARY" &
    PID=$!

    # Poll for window
    TIMEOUT=50
    COUNTER=0
    while [ $COUNTER -lt $TIMEOUT ]; do
        if osascript -e 'tell application "System Events" to exists window 1 of process "mac-menu"' 2>/dev/null | grep -q true; then
            break
        fi
        sleep 0.1
        COUNTER=$((COUNTER + 1))
    done

    END=$(python3 -c 'import time; print(time.time_ns())')
    kill $PID 2>/dev/null

    if [ $COUNTER -ge $TIMEOUT ]; then
        echo "  Run $i: TIMEOUT"
    else
        python3 -c "print(f'  Run $i: {($END - $START) / 1000000:.0f}ms')"
    fi

    sleep 0.2
done
