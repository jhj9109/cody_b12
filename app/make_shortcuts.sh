#!/bin/bash

DIR="./app"

echo "🚀 트러블슈팅 과제용 단축 스크립트 6개를 생성합니다..."

# 1. OOM Crash 테스트용
cat << 'EOF' > $DIR/1_oom_before.sh
#!/bin/bash
echo "[테스트] OOM Crash 발생 (MEMORY_LIMIT: 256MB)"
./app/run_test.sh 256 80 1 "oom_before"
EOF

cat << 'EOF' > $DIR/1_oom_after.sh
#!/bin/bash
echo "[테스트] OOM Crash 해결 (MEMORY_LIMIT: 512MB)"
./app/run_test.sh 512 80 1 "oom_after"
EOF

# 2. CPU Latency 테스트용
cat << 'EOF' > $DIR/2_cpu_before.sh
#!/bin/bash
echo "[테스트] CPU Spike 발생 (CPU_MAX_OCCUPY: 30%)"
./app/run_test.sh 512 30 1 "cpu_before"
EOF

cat << 'EOF' > $DIR/2_cpu_after.sh
#!/bin/bash
echo "[테스트] CPU Spike 해결 (CPU_MAX_OCCUPY: 100%)"
./app/run_test.sh 512 100 1 "cpu_after"
EOF

# 3. Deadlock 테스트용
cat << 'EOF' > $DIR/3_deadlock_before.sh
#!/bin/bash
echo "[테스트] Deadlock 발생 (MULTI_THREAD_ENABLE: 1)"
echo "⚠️ 화면이 완전히 멈추면(무응답) Ctrl+C를 눌러 종료하세요!"
./app/run_test.sh 512 100 1 "deadlock_before"
EOF

cat << 'EOF' > $DIR/3_deadlock_after.sh
#!/bin/bash
echo "[테스트] Deadlock 해결 (MULTI_THREAD_ENABLE: 0 - 단일 스레드)"
./app/run_test.sh 512 100 0 "deadlock_after"
EOF

# 4.추가
cat << 'EOF' > ./app/4_bonus_scheduling.sh
#!/bin/bash
echo "[보너스 과제] 라운드 로빈 스케줄링 패턴 추출용 (스레드 교차 실행 관측)"
# 메모리와 CPU를 넉넉히 주고 멀티스레드를 켜서 패턴만 뽑아냅니다.
./app/run_test.sh 512 100 1 "bonus_rr"
EOF

cat << 'EOF' > ./app/5_ultimate_uptime.sh
#!/bin/bash
echo "[최종 검증] 512MB 환경에서의 최종 생존 시간(Uptime) 측정"
echo "⚠️ OOM으로 강제 종료될 때까지(약 5~10분) 그대로 켜두세요!"
# 데드락과 Watchdog을 모두 끄고, 오직 메모리 누수에 의해서만 죽도록 방치합니다.
./app/run_test.sh 512 100 0 "ultimate_uptime"
EOF

chmod +x $DIR/*.sh

echo "========================================"
echo "✅ 생성이 완료되었습니다! 아래 명령어로 바로 실행하세요."
echo "========================================"
ls -1 $DIR/*.sh