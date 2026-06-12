#!/bin/bash

# 관제 대상 프로세스 이름
PROCESS_NAME="agent-app-leak"
INTERVAL=2 # 화면 갱신 주기 (2초)

# [함수 1] 프로세스 기본 정보 및 상태 체크 (데드락/스레드 분석용)
check_process() {
    PID=$(pgrep -f "$PROCESS_NAME" | head -n 1)
    
    if [ -z "$PID" ]; then
        echo -e "🟢 프로세스 상태: \033[31mNOT_FOUND (종료됨 또는 실행 전)\033[0m"
        return 1
    fi
    
    # ps 명령어로 프로세스 상태(STAT)와 스레드 개수(NLWP) 추출
    # R: Running, S: Sleeping (Sl: 멀티스레드 대기상태)
    STAT=$(ps -p "$PID" -o stat --no-headers | tr -d ' ')
    THREADS=$(ps -p "$PID" -o nlwp --no-headers | tr -d ' ')
    
    echo -e "ℹ️  프로세스 정보: PID=\033[36m$PID\033[0m | 스레드 수(NLWP)=\033[35m$THREADS\033[0m | OS상태(STAT)=\033[33m$STAT\033[0m"
    return 0
}

# [함수 2] 메모리 RSS 정밀 체크 (OOM 분석용)
check_memory() {
    # RSS(물리 메모리 점유 크기)를 KB 단위로 가져옴
    RSS_KB=$(ps -p "$PID" -o rss --no-headers | tr -d ' ')
    # 직관적인 분석을 위해 MB 단위로 환산
    RSS_MB=$(echo "$RSS_KB" | awk '{printf "%.2f", $1/1024}')
    MEM_PCT=$(ps -p "$PID" -o %mem --no-headers | tr -d ' ')
    
    echo -e "🧠 메모리 관제  : 실제물리점유(RSS)=\033[32m${RSS_MB} MB\033[0m (${MEM_PCT}%)"
}

# [함수 3] CPU 사용률 체크 (CPU Spike 분석용)
check_cpu() {
    CPU_PCT=$(ps -p "$PID" -o %cpu --no-headers | tr -d ' ')
    echo -e "⚡ CPU 관제     : 실시간 사용률(%%CPU)=\033[31m${CPU_PCT}%%\033[0m"
}

# [함수 4] 대기 채널 WCHAN 추적 (데드락 스모킹 건 포착용)
check_deadlock() {
    # 프로세스가 커널의 어떤 함수에서 멈춰(Sleep)있는지 커널 함수명 추출
    WCHAN=$(ps -p "$PID" -o wchan --no-headers | tr -d ' ')
    
    echo -n "🔒 교착상태 진단: 커널 대기채널(WCHAN)=[\033[33m$WCHAN\033[0m] "
    
    # 멀티스레드 상태(Sl)이면서 커널 동기화 락 함수인 futex에서 영원히 멈춰있다면 데드락으로 판단
    if [ "$WCHAN" = "futex" ] || [ "$WCHAN" = "futex_" ]; then
        echo -e "➡️  \033[5;31m[🚨 DEADLOCK DETECTED]\033[0m 스레드가 서로 락을 쥐고 futex 파이프에 갇혔습니다."
    else
        echo -e "➡️  \033[32m[NORMAL]\033[0m 자원 경합 없이 정상 스케줄링 중"
    fi
}

# =================================================================
# 메인 반복 루프 (top 명령어처럼 화면을 지우고 주기적으로 함수 호출)
# =================================================================
chmod +x "$0" 2>/dev/null # 스크립트 자체 실행 권한 보장

while true; do
    # 1. 터미널 화면 깨끗하게 비우기 (top 명령어 효과)
    clear
    
    echo "================================================================="
    echo "  📊 실시간 리눅스 커널 레벨 시스템 리소스 관제 대시보드"
    echo "  (갱신 주기: ${INTERVAL}초, 종료: Ctrl+C)"
    echo "================================================================="
    
    # 2. 순서대로 구조화된 함수 호출
    if check_process; then
        echo "-----------------------------------------------------------------"
        check_memory
        check_cpu
        check_deadlock
    fi
    
    echo "================================================================="
    
    # 3. 지정된 주기만큼 대기
    sleep "$INTERVAL"
done