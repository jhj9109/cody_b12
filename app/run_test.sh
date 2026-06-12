#!/bin/bash

# 1. 인자 확인
if [ "$#" -ne 4 ]; then
    echo "사용법: $0 <메모리(MB)> <CPU(%)> <멀티스레드(1/0)> <테스트이름>"
    echo "예시: $0 128 60 0 Test_OOM"
    exit 1
fi

export MEMORY_LIMIT=$1
export CPU_MAX_OCCUPY=$2
export MULTI_THREAD_ENABLE=$3
TEST_NAME=$4

LOG_DIR="/home/codyssey/agent/logs"
mkdir -p "$LOG_DIR"

APP_LOG="$LOG_DIR/${TEST_NAME}_app.log"
MONITOR_LOG="$LOG_DIR/${TEST_NAME}_monitor.log"

echo "=================================================="
echo " 🚀 [CLEAN TEST] $TEST_NAME 실행 중..."
echo " - MEM=$MEMORY_LIMIT | CPU=$CPU_MAX_OCCUPY | THREAD=$MULTI_THREAD_ENABLE"
echo " - 이 테스트는 앱이 자체 에러로 죽을 때까지만 모니터링합니다."
echo "=================================================="

# 2. 로그 파일 초기화
> "$APP_LOG"
> "$MONITOR_LOG"
echo "=== 관제 모니터링 시작 ($TEST_NAME) ===" | tee -a "$MONITOR_LOG"

# -----------------------------------------------------------------
# 🛡️ 수동 종료(Ctrl+C) 대비 Graceful Shutdown 트랩
# -----------------------------------------------------------------
cleanup() {
    if [ -n "$APP_PID" ] && kill -0 $APP_PID 2>/dev/null; then
        echo -e "\n ⚠️ 사용자에 의한 강제 종료 감지! 부드러운 종료(SIGINT)를 시도합니다..."
        kill -2 $APP_PID 2>/dev/null
        wait $APP_PID 2>/dev/null
        echo " 🧹 [Cleanup] Graceful Shutdown 완료."
    fi
}
# trap cleanup SIGINT SIGTERM

# graceful_exit 함수를 강제 종료 버전으로 수정
force_exit() {
    echo -e "\n\n💀 [SYSTEM] 강제 종료(SIGKILL) 요청 감지!"
    
    # 프로세스 그룹 전체를 즉시 처형
    # 부모 프로세스의 PID를 기준으로 그룹 전체를 날리는 것이 가장 안전하고 빠릅니다.
    if [ -n "$APP_PID" ]; then
        echo " ➡️ [APP] 프로세스 그룹($APP_PID) 즉시 처형 중..."
        pkill -9 -P $APP_PID 2>/dev/null # 자식부터 죽임
        kill -9 $APP_PID 2>/dev/null      # 부모 처형
    fi
    
    echo " 🧹 [CLEANUP] 강제 정리 완료."
    exit 0
}

# Ctrl+C에 강제 종료 바인딩
trap force_exit SIGINT
# -----------------------------------------------------------------

# 3. 앱을 백그라운드로 실행 (순수 부모 PID 획득)
./app/agent-app-leak-x86 >> "$APP_LOG" 2>&1 &
APP_PID=$!

sleep 1

# -----------------------------------------------------------------
# 📊 공통 리소스 출력 함수 (KB -> MB 변환 및 정렬)
# -----------------------------------------------------------------
print_stats() {
    local TARGET_PID=$1
    local ROLE_NAME=$2
    local STATS
    
    STATS=$(ps -p $TARGET_PID -o %cpu,%mem,rss,stat,nlwp,wchan --no-headers 2>/dev/null)
    
    if [ -n "$STATS" ]; then
        local CPU=$(echo "$STATS" | awk '{print $1}')
        local MEM=$(echo "$STATS" | awk '{print $2}')
        local RSS_KB=$(echo "$STATS" | awk '{print $3}')
        local STAT=$(echo "$STATS" | awk '{print $4}')
        local NLWP=$(echo "$STATS" | awk '{print $5}')
        local WCHAN=$(echo "$STATS" | awk '{print $6}')
        
        # [핵심] RSS(물리메모리)를 KB에서 MB로 변환 (소수점 2자리)
        local RSS_MB=$(awk "BEGIN {printf \"%d\", $RSS_KB/1024}")
        
        # printf를 사용해 고정폭으로 예쁘게 정렬하여 출력
        printf "  %-4s(PID:%-5s) | CPU:%-6s MEM:%-6s RSS:%-9s STAT:%-5s THREADS:%-2s WCHAN:%s\n" \
               "$ROLE_NAME" "$TARGET_PID" "${CPU}%" "${MEM}%" "${RSS_MB}MB" "$STAT" "$NLWP" "$WCHAN" | tee -a "$MONITOR_LOG"
    else
        printf "  %-4s(PID:%-5s) | ⚠️ 프로세스 정보 없음 (종료 중이거나 이미 종료됨)\n" "$ROLE_NAME" "$TARGET_PID" | tee -a "$MONITOR_LOG"
    fi
}
# -----------------------------------------------------------------

# 4. 모니터링 루프 (앱이 살아있는 동안에만 돈다)
while kill -0 $APP_PID 2>/dev/null; do
    NOW=$(date "+%Y-%m-%d %H:%M:%S")
    
    # 매 주기마다 직계 자식 프로세스를 새로 탐색 (자식이 죽거나 새로 생기는 것 대비)
    CHILD_PID=$(pgrep -P $APP_PID | head -n 1)
    if [ -z "$CHILD_PID" ]; then
        CHILD_PID=$(ps --ppid $APP_PID -o pid= 2>/dev/null | awk '{print $1}')
    fi

    # 시각적 구분선과 시간 헤더 출력
    echo "[$NOW] ⏱️ 관제 주기 갱신" | tee -a "$MONITOR_LOG"
    
    # 부모 프로세스 상태 출력
    print_stats "$APP_PID" "부모"
    
    # 자식 프로세스가 존재하면 출력
    if [ -n "$CHILD_PID" ]; then
        print_stats "$CHILD_PID" "자식"
    fi
    
    # 주기 구분선
    echo "-----------------------------------------------------------------------------------" | tee -a "$MONITOR_LOG"
    
    sleep 2
done

# 5. 종료 판정
wait $APP_PID 2>/dev/null
EXIT_CODE=$?

# [수정] 종료 판정 내용을 화면과 로그 파일에 동시에 기록
{
    echo "--------------------------------------------------"
    echo " 🛑 프로세스가 종료되었습니다. (Exit Code: $EXIT_CODE)"

    if [ $EXIT_CODE -eq 137 ]; then
        echo " 💀 [판정] SIGKILL (137) - OS OOM Killer 개입"
    elif [ $EXIT_CODE -eq 130 ]; then
        echo " ✋ [판정] SIGINT (130) - 사용자(Ctrl+C)에 의한 정상 종료"
    elif [ $EXIT_CODE -ne 0 ]; then
        echo " ⚠️ [판정] 앱 자체 보호 로직 또는 에러 발생 (MemoryGuard / Watchdog 등)"
    else
        echo " 🟢 [판정] 정상 종료"
    fi
    echo " 📁 로그 확인: $APP_LOG"
    echo "=================================================="
} | tee -a "$MONITOR_LOG"