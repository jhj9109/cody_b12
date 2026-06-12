# cody

## 1. OOM Crash 이슈 리포트
[Bug] OOM Crash - MemoryGuard 자발적 보호 정책에 의한 메모리 초과 강제 종료
### 1. Description (현상 설명)
발생 현상: 프로세스 시작후 25MB 단위로 Heap 할당을 추가하다 설정된 리밋 초과로 Self-terminating 됨.

발생 조건: 앱 부팅 시 환경변수로 주입된 MEMORY_LIMIT 값이 256MB 아래로 주어질때 발생

### 2. Evidence & Logs (증거 자료)

애플리케이션 실행 로그 (종료 직전):

```bash
2026-06-12 09:08:24,044 [INFO] [MemoryWorker] Current Heap: 150MB
2026-06-12 09:08:24,044 [CRITICAL] [MemoryGuard] Memory limit exceeded (150MB >= 128MB) / (Recommend Over 256MB)
2026-06-12 09:08:24,044 [CRITICAL] [MemoryGuard] Self-terminating process 21999 to prevent system instability.
```
### 3. Root Cause Analysis (원인 분석)
기술적 원인: 수집된 증거에 따르면 이 장애는 운영체제(Linux Kernel)의 OOM Killer가 kill -9를 날려 발생한 진짜 OS 레벨의 장애가 아닙니다.

동작 원리: 앱 내부에 설계된 MemoryGuard 데몬이 주기적으로 자신의 힙(Heap) 메모리를 감시하다가, MemoryWorker가 누적한 메모리가 할당된 임계치(128MB)를 초과(150MB)한 것을 감지하고 서버 전체의 다운을 막기 위해 소프트웨어적 서킷 브레이커(자결, Self-terminating)를 작동시킨 것입니다.

### 4. Workaround & Verification (조치 및 검증)
조치 내용: 임계치 초과를 막기 위해 테스트 환경변수를 MEMORY_LIMIT=512로 변경하여 실행.

결과 확인 (Before & After):

Before (128MB): 150MB 도달 시점 강제 종료 발생.

After (512MB): OOM 발생 없이 내부적으로 캐시를 비우며([SYSTEM] MEMORY RECOVERED (Cache Cleared)) 메모리 누수를 자체 해결하고 프로세스가 장기 생존함을 확인.
```bash
2026-06-12 08:49:34,975 [INFO] [MemoryWorker] Current Heap: 525MB
2026-06-12 08:49:34,977 [WARNING] [MemoryWorker] Memory Usage Reached Limit (525MB). Starting cleanup...
2026-06-12 08:49:34,986 [INFO] [System] Memory Cache Flushed. Process Stabilized.

>>> [SYSTEM] MEMORY RECOVERED (Cache Cleared) <<<

2026-06-12 08:49:40,017 [INFO] [MemoryWorker] Current Heap: 25MB
```

## 2. CPU Latency 분석 리포트
[Bug] CPU Spike - 임계치 초과 시 CpuWorker 자체 보호 로직(Watchdog)에 의한 실행 중단
### 1. Description (현상 설명)
발생 현상: CPU의 로드가 5%에서 시작하여 점점 오르다 50을 초과하며 "CPU Threshold Violated!" 발생

발생 조건: OOM 발생 하지 않는 환경에서 환경변수 CPU_MAX_OCCUPY가 50 이상일때 발생

### 2. Evidence & Logs (증거 자료)

애플리케이션 실행 로그:

```bash
2026-06-12 09:09:56,603 [INFO] [CpuWorker] Current Load: 50.72%
2026-06-12 09:09:56,704 [CRITICAL] [CpuWorker] CPU Threshold Violated! (50.72%).
```
### 3. Root Cause Analysis (원인 분석)
기술적 원인: 이 역시 커널이 CPU를 많이 쓴다고 프로세스를 강제 종료한 것이 아닙니다. 앱 내부의 CpuWorker 혹은 Watchdog 로직이 현재 자신의 CPU 점유율을 계산하다가, 사전에 주입된 임계치(Threshold)를 넘기자 과점유로 판단하여 스스로 프로세스를 셧다운한 것입니다.

OS 동작 관점: 리눅스 커널은 특정 프로세스가 CPU를 100% 사용하더라도 컨텍스트 스위칭을 통해 다른 프로세스와 자원을 나누게 할 뿐, 100% 점유 자체를 사유로 프로세스를 킬(Kill)하지는 않습니다. 이는 철저히 애플리케이션 내부 정책입니다.

### 4. Workaround & Verification (조치 및 검증)
조치 내용: CPU_MAX_OCCUPY 변수값을 권장치인 30으로 하향 조정하여 실행

결과 확인 (Before & After):

Before: 순간 스파이크 시 50.72%를 기록하며 Watchdog에 의해 Abort 됨.

After: CPU 부하를 올리더라도 상한선 내에서 자체적인 쿨링 앤 로드를 반복하며 한계를 초과하지 않아 프로세스가 무한히 생존함.
```bash
2026-06-12 08:48:45,576 [INFO] [CpuWorker] Peak reached (30.00%). Starting cooldown...
2026-06-12 08:48:46,583 [INFO] [CpuWorker] Current Load: 30.00%
2026-06-12 08:48:49,698 [INFO] [CpuWorker] Current Load: 25.21%
2026-06-12 08:48:52,815 [INFO] [CpuWorker] Current Load: 18.63%
2026-06-12 08:48:55,933 [INFO] [CpuWorker] Current Load: 9.40%
2026-06-12 08:48:59,046 [INFO] [CpuWorker] Current Load: 6.01%
2026-06-12 08:49:01,158 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-06-12 08:49:02,164 [INFO] [CpuWorker] Current Load: 5.00%
```

## 3. 교착상태(DeadLock) 진단 리포트
[Bug] Deadlock - 순환 대기(Circular Wait)로 인한 워커 스레드 영구 무응답 상태
### 1. Description (현상 설명)
발생 현상: 2개의 워커 쓰레드가 각각 자원을 하나씩 점유 후, 서로가 점유한 자원을 기다리며 데드락 발생

발생 조건: OOM과 CPU Latency 발생하지 않는 환경에서 MULTI_THREAD_ENABLE=1 상태로 구동시

### 2. Evidence & Logs (증거 자료)

애플리케이션 실행 로그 (마지막 기록):

```bash
2026-06-12 08:58:38,766 [WARNING] [AgentWorker] Initializing concurrent transaction processors...
2026-06-12 08:58:38,767 [WARNING] [System] CAUTION: Strict resource locking is enabled.
2026-06-12 08:58:43,793 [INFO] [Worker-Thread-1] Process Started. Attempting to lock [Shared_Memory_A]...
2026-06-12 08:58:43,793 [INFO] [AgentWorker][Worker-Thread-2] Process Started. Attempting to lock [Socket_Pool_B]...
2026-06-12 08:58:43,793 [INFO] [AgentWorker] Waiting for worker threads to complete transactions...
2026-06-12 08:58:43,794 [INFO] [AgentWorker][Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
2026-06-12 08:58:43,794 [INFO] [AgentWorker][Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
2026-06-12 08:58:43,795 [INFO] [AgentWorker][Worker-Thread-1] Processing critical data in Memory A...
2026-06-12 08:58:43,795 [INFO] [AgentWorker][Worker-Thread-2] Establishing network connections in Pool B...
2026-06-12 08:58:45,804 [INFO] [AgentWorker][Worker-Thread-2] Need resource [Shared_Memory_A] to write logs.
2026-06-12 08:58:45,804 [INFO] [AgentWorker][Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
2026-06-12 08:58:45,805 [INFO] [AgentWorker][Worker-Thread-1] Need resource [Socket_Pool_B] to finish job.
2026-06-12 08:58:45,806 [INFO] [AgentWorker][Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
```
### 3. Root Cause Analysis (원인 분석)
기술적 원인: 교착상태 4대 조건 중 전형적인 '순환 대기(Circular Wait)' 및 '점유 대기(Hold and Wait)' 상황입니다.

원리 분석: Thread-1은 자원 A를 가진 채 B를 요구하고, Thread-2는 자원 B를 가진 채 A를 요구합니다. 이 상태에서 OS(Linux 커널 스케줄러)는 두 스레드가 서로의 락(Lock)을 영원히 양보하지 않는 논리적 모순을 해결해주지 않으며, 이들은 영구적으로 futex 커널 함수 내부에서 잠들게(Sleep) 됩니다.

### 4. Workaround & Verification (조치 및 검증)
조치 내용: 구조적 결함이 있는 멀티스레드 모드를 비활성화하기 위해 MULTI_THREAD_ENABLE=0 설정 적용.

결과 확인 (Before & After):

Before: 프로세스가 교착상태에 도달하여 어떤 자원도 쓰지 않고 무한 대기

After: 멀티스레드간 경합이 발생하지 않아, 각 쓰레드가 순차적으로 자신의 Task 처리후 정상 진행

```bash
2026-06-12 08:48:33,303 [INFO] [Scheduler] Task Scheduler Initialized.
2026-06-12 08:48:33,303 [INFO] [Scheduler] Registered Tasks: ['Thread-A', 'Thread-B', 'Thread-C']
2026-06-12 08:48:33,303 [INFO] [Scheduler] Starting task execution...
2026-06-12 08:48:33,304 [INFO] [Thread-B] Task Started. Calculating... (20%)
2026-06-12 08:48:33,355 [INFO] [Thread-B] Calculating... (40%)
2026-06-12 08:48:33,407 [INFO] [Thread-B] Calculating... (60%)
2026-06-12 08:48:33,459 [INFO] [Thread-B] Calculating... (80%)
2026-06-12 08:48:33,510 [INFO] [Thread-B] Task Completed. (100%)
2026-06-12 08:48:33,562 [INFO] [Thread-C] Task Started. Calculating... (20%)
2026-06-12 08:48:33,614 [INFO] [Thread-C] Calculating... (40%)
2026-06-12 08:48:33,666 [INFO] [Thread-C] Calculating... (60%)
2026-06-12 08:48:33,717 [INFO] [Thread-C] Calculating... (80%)
2026-06-12 08:48:33,769 [INFO] [Thread-C] Task Completed. (100%)
2026-06-12 08:48:33,821 [INFO] [Thread-A] Task Started. Calculating... (20%)
2026-06-12 08:48:33,872 [INFO] [Thread-A] Calculating... (40%)
2026-06-12 08:48:33,924 [INFO] [Thread-A] Calculating... (60%)
2026-06-12 08:48:33,976 [INFO] [Thread-A] Calculating... (80%)
2026-06-12 08:48:34,028 [INFO] [Thread-A] Task Completed. (100%)
2026-06-12 08:48:34,080 [INFO] [Scheduler] All tasks completed.
```

## 4. 보너스: 스케줄링 알고리즘 추론 리포트 (선택)
[Analysis] 로그 패턴 분석을 통한 스케줄링 알고리즘 역추적
### 1. 로그 관찰 개요
agent-leak-app 내부에 생성된 Worker 스레드들이 작업을 병렬로 처리하는 로그의 타임스탬프와 진행률(Progress)을 분석하여, OS 스케줄러가 이들을 어떤 기법으로 컨텍스트 스위칭(Context Switching) 하는지 역추적했습니다.

### 2. 증거 자료 (Log Snapshot)
```bash
2026-06-12 08:48:33,303 [INFO] [Scheduler] Task Scheduler Initialized.
2026-06-12 08:48:33,303 [INFO] [Scheduler] Registered Tasks: ['Thread-A', 'Thread-B', 'Thread-C']
2026-06-12 08:48:33,303 [INFO] [Scheduler] Starting task execution...
2026-06-12 08:48:33,304 [INFO] [Thread-B] Task Started. Calculating... (20%)
2026-06-12 08:48:33,355 [INFO] [Thread-B] Calculating... (40%)
2026-06-12 08:48:33,407 [INFO] [Thread-B] Calculating... (60%)
2026-06-12 08:48:33,459 [INFO] [Thread-B] Calculating... (80%)
2026-06-12 08:48:33,510 [INFO] [Thread-B] Task Completed. (100%)
2026-06-12 08:48:33,562 [INFO] [Thread-C] Task Started. Calculating... (20%)
2026-06-12 08:48:33,614 [INFO] [Thread-C] Calculating... (40%)
2026-06-12 08:48:33,666 [INFO] [Thread-C] Calculating... (60%)
2026-06-12 08:48:33,717 [INFO] [Thread-C] Calculating... (80%)
2026-06-12 08:48:33,769 [INFO] [Thread-C] Task Completed. (100%)
2026-06-12 08:48:33,821 [INFO] [Thread-A] Task Started. Calculating... (20%)
2026-06-12 08:48:33,872 [INFO] [Thread-A] Calculating... (40%)
2026-06-12 08:48:33,924 [INFO] [Thread-A] Calculating... (60%)
2026-06-12 08:48:33,976 [INFO] [Thread-A] Calculating... (80%)
2026-06-12 08:48:34,028 [INFO] [Thread-A] Task Completed. (100%)
2026-06-12 08:48:34,080 [INFO] [Scheduler] All tasks completed.
```
### 3. 패턴 분석 및 결론
- 선점 여부 (Round-Robin 배제): 하나의 스레드가 작업을 시작하면 100% 완료될 때까지 다른 스레드가 개입(Context Switching)하지 않았습니다. 이는 시간 할당량을 쪼개 쓰는 라운드 로빈(Round-Robin) 방식이 아님을 증명하는 완벽한 비선점형(Non-Preemptive) 특징입니다.

- 실행 순서 (FCFS 배제): 시스템 큐에 등록된 작업의 순서는 [A, B, C]였으나, 실제 CPU를 할당받아 실행된 순서는 B -> C -> A로 완전히 역전되었습니다. 이는 도착한 순서대로 처리하는 FCFS(First-Come, First-Served) 방식이 아님을 증명합니다.

- 최종 결론: 작업의 등록(도착) 순서와 무관하게 내부적인 기준에 따라 B, C, A 순으로 정렬되어 실행되었고, 실행 중에는 제어권을 뺏기지 않았으므로 비선점형 우선순위 스케줄링(Non-Preemptive Priority Scheduling)이 적용된 것으로 강력하게 추론됩니다.
### 4. 아키텍처 관점에서의 평가 (우선순위 스케줄링)
#### 💡 4-1. 기술적 장단점 분석
[ 장점 (Pros) ]

핵심 작업의 절대적 응답성 보장: 시스템 장애 복구, 보안 위협 차단, VIP 사용자 요청 등 비즈니스적으로 '가장 중요한 작업'을 지연 없이 즉각적으로 처리할 수 있습니다.

유연한 자원 통제: 단순한 도착 순서(FCFS)나 시간(RR)이 아니라, 프로세스의 중요도, 메모리 요구량, 데드라인 등 다양한 비즈니스 로직을 우선순위 가중치로 자유롭게 매핑할 수 있습니다.

[ 단점 (Cons) ]

기아 현상 (Starvation): 가장 치명적인 단점입니다. 우선순위가 높은 작업이 큐에 지속적으로 유입될 경우, 우선순위가 낮은 작업(위 로그의 Thread-A)은 CPU를 영원히 할당받지 못하고 무한정 대기하다가 타임아웃 처리될 수 있습니다.

우선순위 역전 (Priority Inversion): 우선순위가 낮은 프로세스가 중요 자원(Lock)을 먼저 선점해버리면, 우선순위가 가장 높은 프로세스가 해당 자원을 기다리며 블로킹(Blocked)되는 모순적인 지연이 발생할 수 있습니다.

※ 엔지니어링 해결책: 단점을 극복하기 위해, 프로세스의 대기 시간이 길어질수록 점진적으로 우선순위를 높여주는 에이징(Aging) 기법을 필수적으로 함께 설계해야 합니다.

#### 🎯 4-2. 서비스 성격에 따른 적용 적합성
추론된 스케줄링 기법을 실제 IT 서비스 아키텍처에 적용할 때의 적합성을 분석했습니다.

[ 부적합한 도메인: 범용 웹/WAS 서버 ]

특징: 일반적인 B2C 서비스 (쇼핑몰, 커뮤니티, SNS 등)

분석: 웹 서버는 수만 명의 사용자가 '동시에 응답받고 있다'고 느끼게 하는 공평성이 최우선입니다. 우선순위 스케줄링을 적용할 경우, 특정 유저(낮은 순위)의 브라우저 화면이 영원히 로딩 중(White Screen)에 빠지는 기아 현상이 발생하므로 매우 부적합합니다. (이러한 시스템은 라운드 로빈(Round-Robin)이 압도적으로 유리합니다.)

[ 적합한 도메인: 실시간 시스템(RTOS) 및 미션 크리티컬 백엔드 ]

특징: 금융(FDS 이상거래탐지), 자율주행, 의료 기기, 공장 제어 시스템, 서버 헬스체크 데몬

분석: "모두에게 공평한 것"보다 "가장 중요한 작업을 데드라인 안에 반드시 끝내는 것"이 생명이나 막대한 자본과 직결되는 환경에 완벽하게 부합합니다. 예를 들어 일반 데이터 동기화 배치 작업보다, 해킹 시도 차단이나 에어백 전개 같은 프로세스에 최우선 순위를 부여하여 다른 모든 작업을 멈추고(혹은 대기시키고) 즉시 실행되도록 설계해야 합니다.

## 5. Troubleshooting Methodology & Insights
5.1 관제 도구 및 진단 기법
메모리 누수 관제 (monitor.sh): ps -p $PID -o rss= 명령어를 사용하여 프로세스의 물리 메모리 사용량을 KB 단위로 2초마다 추출하였습니다. 이를 awk로 파싱하여 25MB 단위로 급증하는 선형 증가 패턴을 시각화했습니다.

CPU 관제 도구: top 및 ps -o %cpu를 사용하여 스파이크를 식별했습니다. 특히 ps의 %cpu는 프로세스 시작 시점부터의 평균치가 아니라, 커널이 계산한 최근 CPU 점유율을 반영하므로 순간적인 스파이크 감지에 유용합니다.

데드락 외부 식별 프로세스: ps -L -p $PID 명령을 통해 스레드 상태를 확인하고, cat /proc/$PID/stack 명령을 통해 프로세스가 futex_wait 커널 함수에서 멈춰 있음을 확인하여 논리적 교착 상태를 식별했습니다.

5.2 장애 분석 철학
CPU 과점유 보호: 단일 프로세스의 CPU 점유 제한은 특정 워커 스레드의 무한 루프가 전체 시스템의 CPU를 독점하여, 운영체제의 다른 시스템 프로세스(로그 데몬, SSH 접속 등)가 응답 불능(Hang)에 빠지는 것을 방지하기 위한 '최후의 방어선'입니다.

치명도 분석: 3가지 장애 중 실제 서비스에서 가장 치명적인 것은 데드락입니다. OOM은 프로세스 재시작으로, CPU 과점유는 스로틀링으로 완화 가능하지만, 데드락은 프로세스가 죽지도 않고 응답만 멈춘 '좀비 상태'가 되어 외부 로드밸런서가 장애를 감지하지 못하고 지속적으로 트래픽을 전송하기 때문입니다.

예방책: 메모리 누수는 정기적인 힙 덤프 분석 및 캐시 TTL 적용, 데드락은 락 획득 순서의 표준화(Lock Ordering)와 타임아웃 처리가 필수적입니다.

장애 대응 우선순위: 1. OOM: 서비스 정지 직결, 즉시 탐지 및 메모리 증설/캐시 초기화 우선.
2. 데드락: 외부 감지가 어려우므로 정기적인 상태 확인(Health Check) 수행.
3. CPU 과점유: 성능 저하 수준이므로 후순위 조치.

5.3 코드 레벨 개선 제안
OOM: MemoryGuard를 단순 킬(Kill)이 아닌, 캐시 메모리를 강제 비우는 LRU(Least Recently Used) 방출 정책으로 고도화.

CPU: CpuWorker가 임계치를 넘을 경우, 프로세스 종료 대신 스레드 우선순위를 낮추는 renice 전략 적용.

Deadlock: 모든 자원 획득 시 획득 대기 시간(TryLock with Timeout)을 강제하여, 데드락 발생 시 스스로 락을 풀고 재시도하도록 수정.

5.4 회고 및 개선 방향
이전에는 단순히 환경변수를 조정하는 '임시 처방'에 의존했으나, 다시 수행한다면 프로세스의 상태(STAT) 변화와 커널 대기 채널(WCHAN)을 실시간으로 추적하는 통합 대시보드를 먼저 구축하겠습니다. 또한, 장애 발생 시 덤프를 생성(gcore)하여 장애 당시의 메모리 힙 구조를 분석하는 단계를 추가하여 근본 원인을 더 명확히 규명하겠습니다.