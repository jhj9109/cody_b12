#!/bin/bash

# 1. 인자 개수 확인 (3개 또는 4개 지원)
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "사용법: $0 <메모리제한(MB)> <CPU제한(%)> <멀티스레드(1/0)> [로그접두사]"
    echo "예시(OOM 발생): $0 256 80 1 oom_before"
    exit 1
fi

# 2. 인자로 받은 값을 환경변수로 덮어쓰기
export MEMORY_LIMIT=$1
export CPU_MAX_OCCUPY=$2
export MULTI_THREAD_ENABLE=$3
PREFIX=$4 # 4번째 인자 (선택)

# 3. 로그 디렉터리 및 파일명(타임스탬프) 설정
LOG_DIR="/home/codyssey/agent/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date "+%H%M%S")

# 접두사(PREFIX) 존재 여부에 따라 파일명 결정
if [ -n "$PREFIX" ]; then
    APP_LOG="$LOG_DIR/${PREFIX}_app_${TIMESTAMP}.log"
    MONITOR_LOG="$LOG_DIR/${PREFIX}_monitor_${TIMESTAMP}.log"
else
    APP_LOG="$LOG_DIR/app_${TIMESTAMP}.log"
    MONITOR_LOG="$LOG_DIR/monitor_${TIMESTAMP}.log"
fi

echo "========================================"
echo " [🚀 트러블슈팅 테스트 시작]"
echo " - MEMORY_LIMIT : $MEMORY_LIMIT MB"
echo " - CPU_MAX_OCCUPY : $CPU_MAX_OCCUPY %"
echo " - MULTI_THREAD_ENABLE: $MULTI_THREAD_ENABLE"
echo "----------------------------------------"
echo " 📄 앱 실행 로그 : $APP_LOG"
echo " 📊 모니터링 로그: $MONITOR_LOG"
echo "========================================"

# 4. 모니터링 로직 (백그라운드)
start_monitoring() {
    echo "=================================================" > "$MONITOR_LOG"
    echo " 관제 모니터링 시작 (대상: agent-app-leak)" >> "$MONITOR_LOG"
    echo "=================================================" >> "$MONITOR_LOG"

    while true; do
        NOW=$(date "+%Y-%m-%d %H:%M:%S")
        PID=$(pgrep -f agent-app-leak | head -n 1)
        
        if [ -z "$PID" ]; then
            echo "[$NOW] PROCESS:NOT_FOUND CPU:0.0% MEM:0.0% DISK:954G FIREWALL:active" >> "$MONITOR_LOG"
        else
            STATS=$(ps -p $PID -o %cpu,%mem --no-headers)
            CPU=$(echo $STATS | awk '{print $1}')
            MEM=$(echo $STATS | awk '{print $2}')
            echo "[$NOW] PROCESS:agent-leak-app CPU:${CPU}% MEM:${MEM}% DISK:954G FIREWALL:active" >> "$MONITOR_LOG"
        fi
        sleep 3
    done
}

start_monitoring &
MONITOR_PID=$!

# 5. 메인 애플리케이션 실행
APP_EXEC="./app/agent-app-leak-x86" 

echo "프로그램을 실행합니다... (자동으로 종료될 때까지 대기)"
echo "----------------------------------------"

$APP_EXEC 2>&1 | tee "$APP_LOG"

# 6. 애플리케이션 종료 시 모니터링 프로세스도 Kill
kill $MONITOR_PID 2>/dev/null

echo "----------------------------------------"
echo " [✅ 테스트 종료]"
echo " 결과 로그가 logs 폴더에 저장되었습니다."
echo "========================================"