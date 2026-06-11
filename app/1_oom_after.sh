#!/bin/bash
echo "[테스트] OOM Crash 해결 (MEMORY_LIMIT: 512MB)"
./app/run_test.sh 512 80 1 "oom_after"
