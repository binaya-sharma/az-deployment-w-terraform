FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Java 17 for Spark/Databricks
RUN apt-get update && \
    apt-get install -y \
    openjdk-17-jdk \
    curl \
    jq \
    gnupg \
    software-properties-common \
    lsb-release && \
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


WORKDIR /azure-deployment-w-terraform