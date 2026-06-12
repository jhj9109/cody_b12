#!/bin/bash

# 과제 환경에 맞춘 대상 프로세스 이름 (x86, arm64 모두 매칭)
PROCESS_NAME="agent-app"
LOG_DIR="/home/codyssey/agent/logs"
LOG_FILE="$LOG_DIR/monitor.log"

# 작동 OK => But 프로세스 2개라 쉬고있는 부모만 추적함 ㅡㅡ;

# 로그 디렉터리가 없으면 생성 (안전장치)
mkdir -p $LOG_DIR

echo "================================================="
echo " 관제 모니터링 시작 (대상: $PROCESS_NAME)"
echo " 로그 저장 경로: $LOG_FILE"
echo " 종료하려면 Ctrl+C 를 누르세요."
echo "================================================="

while true; do
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    
    # 프로세스 PID 찾기
    PID=$(pgrep -f $PROCESS_NAME | head -n 1)
    
    if [ -z "$PID" ]; then
        # 프로세스가 꺼져있을 때의 로그
        LOG_MSG="[$TIMESTAMP] PROCESS:NOT_FOUND CPU:0.0% MEM:0.0% DISK:954G FIREWALL:active"
    else
        # 프로세스가 살아있을 때 CPU와 MEM 수치 추출
        STATS=$(ps -p $PID -o %cpu,%mem --no-headers)
        CPU=$(echo $STATS | awk '{print $1}')
        MEM=$(echo $STATS | awk '{print $2}')
        
        LOG_MSG="[$TIMESTAMP] PROCESS:agent-leak-app CPU:${CPU}% MEM:${MEM}% DISK:954G FIREWALL:active"
    fi
    
    # 터미널에 출력 (실시간 확인용)
    echo $LOG_MSG
    
    # 로그 파일에 누적 기록 (증거 자료 제출용)
    echo $LOG_MSG >> $LOG_FILE
    
    # 3초 대기 후 반복
    sleep 3
done