# 1. 복사할 목적지 폴더가 없다면 먼저 생성합니다.
mkdir -p temp

# 2. 루프를 돌며 파일명만 추출한 뒤 확장자를 바꿔 복사합니다.
for f in logs/*.log; do
    # f에서 경로와 .log를 제외한 순수 파일명만 추출 (예: logs/oom_app.log -> oom_app)
    filename=$(basename "$f" .log)
    
    # temp 폴더로 .txt 확장자를 붙여 복사 실행
    cp "$f" "temp/${filename}.txt"
done