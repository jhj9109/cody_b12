#!/bin/bash
echo "[테스트] Deadlock 발생 (MULTI_THREAD_ENABLE: 1)"
echo "⚠️ 화면이 완전히 멈추면(무응답) Ctrl+C를 눌러 종료하세요!"
./app/run_test.sh 512 100 1 "deadlock_before"
