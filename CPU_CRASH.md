# CPU_CRASH

## 전체로그
```bash
>>> Starting Agent Boot Sequence...
[1/6] Checking User Account               [OK]
   ... Running as service user 'codyssey' (uid=1000)
[2/6] Verifying Environment Variables     [OK]
   ... All required Envs correct
[3/6] Checking Required Files             [OK]
   ... Verified 'secret.key' with correct key string.
[4/6] Checking Port Availability          [OK]
   ... Port 15034 is available.
[5/6] Verifying Log Permission            [OK]
   ... Log directory is writable: /home/codyssey/agent/logs
[6/6] Verifying Mission Environment       [OK]
   ... MEMORY_LIMIT=512MB, CPU_MAX_OCCUPY=100%, MULTI_THREAD_ENABLE=False
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
2026-06-12 09:09:26,554 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-06-12 09:09:26,554 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check
==================================================
 [ MEMORY ] Limit: 512MB 		[ OK ]
 [ CPU    ] Limit: 100%  		[ WARNING: Recommend Under 50% ]
 [ THREAD ] Concurrency: False 		[ OK ]
--------------------------------------------------
 >>> SYSTEM STATUS: STABLE. STARTING WORKLOAD MONITORING...
==================================================

2026-06-12 09:09:28,564 [INFO] [CpuWorker] Started. Maximum CPU Limit: 100%
2026-06-12 09:09:28,565 [INFO] [CpuWorker] Current Load: 5.00%
2026-06-12 09:09:31,682 [INFO] [CpuWorker] Current Load: 10.57%
2026-06-12 09:09:34,799 [INFO] [CpuWorker] Current Load: 14.01%
2026-06-12 09:09:37,915 [INFO] [CpuWorker] Current Load: 15.12%
2026-06-12 09:09:41,031 [INFO] [CpuWorker] Current Load: 18.00%
2026-06-12 09:09:44,141 [INFO] [CpuWorker] Current Load: 21.46%
2026-06-12 09:09:47,255 [INFO] [CpuWorker] Current Load: 27.22%
2026-06-12 09:09:50,371 [INFO] [CpuWorker] Current Load: 36.43%
2026-06-12 09:09:53,489 [INFO] [CpuWorker] Current Load: 44.82%
2026-06-12 09:09:56,603 [INFO] [CpuWorker] Current Load: 50.72%
2026-06-12 09:09:56,704 [CRITICAL] [CpuWorker] CPU Threshold Violated! (50.72%).
```