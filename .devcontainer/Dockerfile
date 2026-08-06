FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Java 17 for Spark/Databricks
RUN apt-get update && \
    apt-get install -y \
    openjdk-17-jdk \
    curl \
    jq \
    gnupg \
    make \
    shellcheck \
    software-properties-common \
    lsb-release \
    unzip \
    zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


# Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash


# Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| tee /etc/apt/sources.list.d/hashicorp.list

RUN apt-get update && \
    apt-get install -y terraform


# Databricks CLI
RUN curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh

# Codex CLI
# Install for the non-root user used by VS Code and keep its binary on PATH.
USER vscode
ENV PATH="/home/vscode/.local/bin:${PATH}"
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    uv --version

RUN curl -fsSL https://chatgpt.com/codex/install.sh | sh && \
    codex --version

WORKDIR /workspaces/azure-deployment-w-terraform
