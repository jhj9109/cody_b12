#!/bin/bash
echo "[테스트] OOM Crash 발생 (MEMORY_LIMIT: 256MB)"
./app/run_test.sh 256 80 1 "oom_before"
