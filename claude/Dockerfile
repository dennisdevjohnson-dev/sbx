# sbx template: Docker's official Claude Code sandbox + the AWS toolbelt. GENERIC — no account values.
# Badge profiles are written at sandbox start by `aws-badge` from env supplied by the kit / -e.
FROM docker/sandbox-templates:claude-code
LABEL org.opencontainers.image.source="https://github.com/dennisdevjohnson-dev/sbx" \
      org.opencontainers.image.description="Claude Code sandbox template: AWS CLI + Terraform + aws-badge. No credentials baked in." \
      org.opencontainers.image.version="1.1.0"

ARG TERRAFORM_VERSION=1.16.1
ARG NPM_VERSION=11.19.1
ARG TARGETARCH

USER root
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends unzip jq less \
      iputils-ping dnsutils netcat-openbsd traceroute iproute2 telnet \
    && rm -rf /var/lib/apt/lists/*
# Ubuntu's apt `npm` unbundles its dependencies into /usr/share/nodejs, and those Debian node-*
# libraries carry nearly every npm CVE the scanners report. Nothing here uses them — Claude Code
# is a native binary, the AWS CLI bundles its own Python, Terraform is a static Go binary — so
# purge the stack and restore a self-contained upstream npm. node, git and curl are untouched.
# node-brace-expansion/minimatch/undici/semver stay: `nodejs` itself depends on them.
RUN apt-get update \
    && apt-get purge -y npm && apt-get autoremove --purge -y \
    && curl -fsSL "https://registry.npmjs.org/npm/-/npm-${NPM_VERSION}.tgz" -o /tmp/npm.tgz \
    && mkdir -p /usr/local/lib/node_modules/npm \
    && tar -xzf /tmp/npm.tgz -C /usr/local/lib/node_modules/npm --strip-components=1 \
    && ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && rm -f /tmp/npm.tgz && rm -rf /var/lib/apt/lists/*
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
# The template pins whatever Claude Code was current when Docker built it. Pull the release that
# is current at OUR build time and drop the superseded version tree the updater leaves behind.
RUN claude update \
    && CUR=$(readlink -f /home/agent/.local/bin/claude) \
    && find /home/agent/.local/share/claude/versions -mindepth 1 -maxdepth 1 ! -path "$CUR" -exec rm -rf {} + \
    && claude --version
