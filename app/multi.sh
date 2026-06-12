#!/bin/bash

# 검색할 타겟 프로세스 키워드
TARGET="agent-app"

# 화면 클리어 (탑 명령어처럼 제자리 갱신)
printf "\033c"

while true; do
    # 1. 대상 키워드를 포함하는 모든 PID를 검색 (콤마로 구분하여 추출)
    PIDS=$(pgrep -d, -f "$TARGET")

    # 터미널 커서를 맨 위로 이동시켜 깜빡임 없이 화면 갱신
    printf "\033[1;1H\033[2J"
    echo "====================================================================================="
    echo " 👨‍👦 [멀티 프로세스 패밀리 트리 관제 대시보드] (대상: $TARGET)"
    echo "====================================================================================="

    if [ -z "$PIDS" ]; then
        echo " ⏳ [$(date +'%H:%M:%S')] '$TARGET' 관련 프로세스가 실행되기를 기다리는 중..."
    else
        echo " 🚀 [$(date +'%H:%M:%S')] 다중 프로세스 감지됨!"
        echo "-------------------------------------------------------------------------------------"
        # 헤더 부분도 동일한 간격으로 맞춤
        printf " %-7s | %-12s | %-6s | %-6s | %-5s | %-10s | %s\n" \
               "PID" "PPID(부모)" "CPU(%)" "MEM(%)" "STAT" "WCHAN" "CMD"
        echo "-------------------------------------------------------------------------------------"
        
        # 2. ps 명령어로 감지된 모든 PID의 상세 정보 출력
        # 커스텀 포맷: pid, ppid, cpu, mem, 상태, 대기채널, 실행명령어
        ps -p "$PIDS" -o pid=,ppid=,%cpu=,%mem=,stat=,wchan=,args= | while read -r line; do
            # 추출된 라인을 분석하여 변수에 담기
            _PID=$(echo "$line" | awk '{print $1}')
            _PPID=$(echo "$line" | awk '{print $2}')
            _CPU=$(echo "$line" | awk '{print $3}')
            _MEM=$(echo "$line" | awk '{print $4}')
            _STAT=$(echo "$line" | awk '{print $5}')
            _WCHAN=$(echo "$line" | awk '{print $6}')
            # 7번째 항목부터 끝까지는 모두 CMD(실행 명령어)로 묶음
            _CMD=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=""; sub(/^[ \t]+/, ""); print $0}')
            
            # 고정폭 출력 (printf)
            # %-7s : 7칸 차지, 좌측 정렬 / %6s : 6칸 차지, 우측 정렬
            if [ "$_PPID" -eq 1 ]; then
                # 고아 프로세스 강조 (Init)
                printf " \033[36m%-7s\033[0m | \033[31m%-12s\033[0m | %-6s | %-6s | %-5s | %-10s | %s\n" \
                       "$_PID" "1(Init)" "$_CPU" "$_MEM" "$_STAT" "$_WCHAN" "$_CMD"
            else
                # 일반 부모-자식 프로세스
                printf " \033[36m%-7s\033[0m | \033[33m%-12s\033[0m | %-6s | %-6s | %-5s | %-10s | %s\n" \
                       "$_PID" "$_PPID" "$_CPU" "$_MEM" "$_STAT" "$_WCHAN" "$_CMD"
            fi
        done
    fi
    
    echo "====================================================================================="
    sleep 1
done