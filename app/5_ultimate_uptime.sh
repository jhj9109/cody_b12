#!/bin/bash
echo "[최종 검증] 512MB 환경에서의 최종 생존 시간(Uptime) 측정"
echo "⚠️ OOM으로 강제 종료될 때까지(약 5~10분) 그대로 켜두세요!"
# 데드락과 Watchdog을 모두 끄고, 오직 메모리 누수에 의해서만 죽도록 방치합니다.
./app/run_test.sh 512 100 0 "ultimate_uptime"
