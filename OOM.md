# OOM

## 전체 로그
```bash
All Boot Checks Passed!
Agent READY
2026-06-12 09:08:06,778 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-06-12 09:08:06,778 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check
==================================================
 [ MEMORY ] Limit: 128MB 		[ WARNING: Recommend Over 256MB ]
 [ CPU    ] Limit: 30%  		[ OK ]
 [ THREAD ] Concurrency: False 		[ OK ]
--------------------------------------------------
 >>> SYSTEM STATUS: STABLE. STARTING WORKLOAD MONITORING...
==================================================

2026-06-12 09:08:08,818 [INFO] [MemoryWorker] Current Heap: 25MB
2026-06-12 09:08:11,861 [INFO] [MemoryWorker] Current Heap: 50MB
2026-06-12 09:08:14,905 [INFO] [MemoryWorker] Current Heap: 75MB
2026-06-12 09:08:17,953 [INFO] [MemoryWorker] Current Heap: 100MB
2026-06-12 09:08:20,998 [INFO] [MemoryWorker] Current Heap: 125MB
2026-06-12 09:08:24,044 [INFO] [MemoryWorker] Current Heap: 150MB
2026-06-12 09:08:24,044 [CRITICAL] [MemoryGuard] Memory limit exceeded (150MB >= 128MB) / (Recommend Over 256MB)
2026-06-12 09:08:24,044 [CRITICAL] [MemoryGuard] Self-terminating process 21999 to prevent system instability.
```