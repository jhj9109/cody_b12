#!/bin/bash

# 추적할 프로세스 이름 및 갱신 주기
TARGET_NAME="agent-app-leak-x86"
INTERVAL=1

echo "================================================================"
echo " 🎯 [$TARGET_NAME] 정밀 리소스 추적기 (갱신: ${INTERVAL}초)"
echo "================================================================"

# 무한 반복 (프로세스가 죽어도 다시 켜질 때까지 대기하기 위함)
while true; do
    
    # 1. 프로세스 찾기 (실행 명령어 기준)
    PID=$(pgrep -f "$TARGET_NAME" | head -n 1)

    # PID를 못 찾았으면 대기 상태 출력 후 1초 뒤 다시 확인
    if [ -z "$PID" ]; then
        # \r을 사용하여 터미널 줄바꿈 없이 제자리에서 대기 상태만 갱신
        echo -ne "\r[$(date +'%H:%M:%S')] ⏳ '$TARGET_NAME' 실행을 기다리는 중..."
        sleep 1
        continue
    fi

    # 1번에서 찾았으면 본격적인 모니터링 시작
    echo -e "\n\n🚀 [$(date +'%H:%M:%S')] 프로세스 발견! (PID: $PID) 정밀 추적 시작"
    echo "----------------------------------------------------------------"
    echo " 시간        | CPU(%) | MEM(%) | 물리메모리(RSS) | 스레드수 "
    echo "----------------------------------------------------------------"

    # 2. 프로세스가 살아있는(kill -0) 동안 정밀 조회 반복
    while kill -0 $PID 2>/dev/null; do
        NOW=$(date +'%H:%M:%S')

        # [핵심 로직] 실시간 CPU 점유율 정밀 추출
        # top을 1초 간격(-d 1)으로 2번(-n 2) 실행합니다.
        # 첫 번째 결과(누적치)는 버리고, 1초 동안 측정된 두 번째 결과(실시간)만 추출합니다.
        # (이 명령어 자체가 1초의 딜레이를 발생시키므로 별도의 sleep이 필요 없습니다)
        TOP_OUT=$(top -b -n 2 -d $INTERVAL -p $PID 2>/dev/null | grep "^ *$PID" | tail -n 1)

        # 프로세스가 방금 죽어서 top 결과를 못 가져왔다면 inner loop 탈출
        if [ -z "$TOP_OUT" ]; then
            break 
        fi

        # top 출력물에서 9번째(CPU), 10번째(MEM) 컬럼 추출
        CPU_PCT=$(echo "$TOP_OUT" | awk '{print $9}')
        MEM_PCT=$(echo "$TOP_OUT" | awk '{print $10}')

        # ps 명령어로 정확한 물리 메모리(KB)와 스레드 수 추출
        PS_OUT=$(ps -p $PID -o rss,nlwp --no-headers 2>/dev/null)
        if [ -n "$PS_OUT" ]; then
            RSS_KB=$(echo "$PS_OUT" | awk '{print $1}')
            # 보기 편하게 MB 단위로 소수점 둘째 자리까지 환산
            RSS_MB=$(awk "BEGIN {printf \"%.2f\", $RSS_KB/1024}")
            THREADS=$(echo "$PS_OUT" | awk '{print $2}')

            # 보기 좋게 표 형태로 정렬하여 출력
            printf " %-10s | \033[31m%-6s\033[0m | \033[32m%-6s\033[0m | %-13s | %-8s \n" \
                   "$NOW" "${CPU_PCT}%" "${MEM_PCT}%" "${RSS_MB} MB" "$THREADS"
        fi
    done

    # 3. while 문을 빠져나왔다는 것은 프로세스가 죽었다는 의미
    echo "----------------------------------------------------------------"
    echo "🚨 [$(date +'%H:%M:%S')] 프로세스(PID: $PID)가 종료되었습니다."
    echo "================================================================"
    
    # 프로세스가 사라졌으므로 최상단(1번)으로 돌아가서 다시 대기 시작
done