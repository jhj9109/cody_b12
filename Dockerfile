# 베이스 이미지는 기본적인 도구 활용이 편한 Ubuntu 사용
FROM ubuntu:22.04

# 1. 필수 리눅스 시스템 도구 설치 (캐싱됨) 
RUN apt-get update && apt-get install -y \
    procps \
    htop \
    psmisc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 2. 일반 사용자 생성 (과제 조건: root가 아닌 일반 사용자) [cite: 82]
RUN useradd -m -s /bin/bash codyssey

# 3. 환경변수 기본 세팅 (과제 조건: AGENT_HOME 설정 필수) [cite: 82]
ENV AGENT_HOME=/home/codyssey/agent
ENV AGENT_PORT=15034
ENV AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
ENV AGENT_LOG_DIR=$AGENT_HOME/logs
ENV AGENT_KEY_PATH=$AGENT_HOME/api_keys

# 4. 필수 디렉터리 생성 및 권한 부여 [cite: 86]
RUN mkdir -p $AGENT_UPLOAD_DIR $AGENT_KEY_PATH $AGENT_LOG_DIR
RUN chown -R codyssey:codyssey $AGENT_HOME

# 5. 필수 키 파일 생성 및 권한 부여 [cite: 86]
RUN echo "agent_api_key_test" > $AGENT_KEY_PATH/secret.key && \
    chown codyssey:codyssey $AGENT_KEY_PATH/secret.key

# 6. 사용자 변경 및 작업 디렉터리 설정
USER codyssey
WORKDIR $AGENT_HOME

# 컨테이너가 바로 종료되지 않도록 무한 대기 (바이너리는 터미널 접속 후 수동 실행)
CMD ["tail", "-f", "/dev/null"]