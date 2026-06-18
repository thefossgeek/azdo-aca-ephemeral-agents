FROM alpine:3.20

# musl-x64 targets Alpine's native musl libc — no glibc shim needed
ENV TARGETARCH="linux-musl-x64"

RUN apk add --no-cache \
  bash \
  ca-certificates \
  curl \
  git \
  icu-libs \
  jq \
  libgcc \
  libstdc++

WORKDIR /azp/

# Agent binary is pre-downloaded by download-agent.sh — no internet needed at build time
COPY ./agent.tar.gz /tmp/agent.tar.gz
RUN tar -xz -f /tmp/agent.tar.gz \
    && rm /tmp/agent.tar.gz

COPY ./start.sh ./
RUN chmod +x ./start.sh

RUN adduser -D -h /home/agent agent \
  && chown -R agent:agent /azp /home/agent

USER agent

ENTRYPOINT ["/bin/bash", "./start.sh"]
