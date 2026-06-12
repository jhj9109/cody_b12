#!/bin/bash

echo "=================================================="
echo " 🔍 시스템 내 좀비 프로세스 탐색 중..."
echo "=================================================="

# 1. STAT 상태가 'Z' (Zombie)인 프로세스의 PID와 PPID(부모 PID)를 추출
# awk '$3=="Z"' -> 3번째 컬럼(상태)이 Z인 것만 필터링
ZOMBIES=$(ps -eo pid,ppid,stat,cmd | awk '$3=="Z" || $3=="Z+"')

if [ -z "$ZOMBIES" ]; then
    echo " ✅ 현재 시스템에 좀비 프로세스가 없습니다."
    exit 0
fi

echo "🧟 발견된 좀비 프로세스들:"
echo "$ZOMBIES"
echo "--------------------------------------------------"

# 2. 좀비 프로세스들의 부모 PID(PPID)만 추출 후 중복 제거
PPIDS=$(echo "$ZOMBIES" | awk '{print $1}' | sort | uniq)

echo "🔫 좀비의 부모 프로세스 처형을 시작합니다..."

for ppid in $PPIDS; do
    # 안전장치: OS의 핵심인 PID 1은 절대 건드리지 않음
    if [ "$ppid" -eq 1 ]; then
        echo " ⚠️  PPID 1 (init/systemd)은 강제 종료할 수 없습니다."
        continue
    fi

    # 부모 프로세스 이름 확인
    P_NAME=$(ps -p $ppid -o comm= 2>/dev/null)
    echo " 👉 타겟 부모 프로세스: PID $ppid ($P_NAME)"

    # 1단계: 부모에게 "너네 자식 죽었으니 수거해라" 라는 부드러운 신호(SIGCHLD) 전송
    kill -s SIGCHLD $ppid 2>/dev/null
    sleep 1

    # 2단계: 여전히 부모가 살아있고 좀비를 방치한다면, 부모를 강제 종료(SIGKILL) 시킴
    if ps -p $ppid > /dev/null 2>&1; then
        echo "    🚨 부모가 응답하지 않아 강제 종료(kill -9) 합니다."
        kill -9 $ppid 2>/dev/null
    else
        echo "    ✅ 부모가 정상적으로 좀비를 수거했습니다."
    fi
done

echo "=================================================="
echo " 🧹 좀비 프로세스 청소 완료! (top 명령어로 다시 확인해보세요)"
echo "=================================================="