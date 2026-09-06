# sbx template: Docker's official Claude Code sandbox + the AWS toolbelt. GENERIC — no account values.
# Badge profiles are written at sandbox start by `aws-badge` from env supplied by the kit / -e.
FROM docker/sandbox-templates:claude-code
LABEL org.opencontainers.image.source="https://github.com/dennisdevjohnson-dev/sbx" \
      org.opencontainers.image.description="Claude Code sandbox template: AWS CLI + Terraform + aws-badge. No credentials baked in."

ARG TERRAFORM_VERSION=1.16.1
ARG TARGETARCH

USER root
RUN apt-get update && apt-get install -y --no-install-recommends unzip jq less \
      iputils-ping dnsutils netcat-openbsd traceroute iproute2 telnet \
    && rm -rf /var/lib/apt/lists/*
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo aarch64 || echo x86_64) \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o /tmp/awscli.zip \
    && unzip -q /tmp/awscli.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscli.zip
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo arm64 || echo amd64) \
    && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" -o /tmp/tf.zip \
    && unzip -q /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip
COPY aws-badge /usr/local/bin/aws-badge
COPY README.md /etc/sandbox/README.md
RUN chmod +x /usr/local/bin/aws-badge
USER agent
