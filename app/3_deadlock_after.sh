#!/bin/bash
echo "[테스트] Deadlock 해결 (MULTI_THREAD_ENABLE: 0 - 단일 스레드)"
./app/run_test.sh 512 100 0 "deadlock_after"
