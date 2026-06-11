#!/bin/bash
echo "[테스트] CPU Spike 해결 (CPU_MAX_OCCUPY: 100%)"
./app/run_test.sh 512 100 1 "cpu_after"
