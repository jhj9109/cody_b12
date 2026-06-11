#!/bin/bash
echo "[테스트] CPU Spike 발생 (CPU_MAX_OCCUPY: 30%)"
./app/run_test.sh 512 30 1 "cpu_before"
