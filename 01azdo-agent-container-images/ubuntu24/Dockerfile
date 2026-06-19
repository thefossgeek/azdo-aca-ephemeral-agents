FROM mcr.microsoft.com/azure-powershell:ubuntu-24.04

# glibc-x64 targets Ubuntu's native glibc
ENV TARGETARCH="linux-x64"

# Prevent interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    iputils-ping \
    libicu74 \
    libcurl4 \
    libunwind8 \
    netcat-openbsd \
    unzip \
    dnsutils \
  && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

WORKDIR /azp/

# Agent binary is pre-downloaded by download-agent.sh — no internet needed at build time
COPY ./agent.tar.gz /tmp/agent.tar.gz
RUN tar -xz -f /tmp/agent.tar.gz \
    && rm /tmp/agent.tar.gz

COPY ./start.sh ./
RUN chmod +x ./start.sh

RUN useradd -m -d /home/agent agent \
  && chown -R agent:agent /azp /home/agent

USER agent

ENTRYPOINT ["/bin/bash", "./start.sh"]
