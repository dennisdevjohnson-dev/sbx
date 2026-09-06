# claude-extra-tools: the base template + editor and diagram extras that may not be allowed at work.
#   Helix (hx) + terraform-ls (HCL go-to-definition) + the archify diagram skill.
FROM ghcr.io/dennisdevjohnson-dev/claude-base-tools:v1
LABEL org.opencontainers.image.source="https://github.com/dennisdevjohnson-dev/sbx" \
      org.opencontainers.image.description="claude-base-tools + Helix, terraform-ls, archify."

ARG HELIX_VERSION=25.07.1
ARG TFLS_VERSION=0.36.5
ARG TARGETARCH

USER root
RUN apt-get update && apt-get install -y --no-install-recommends xz-utils && rm -rf /var/lib/apt/lists/*
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo aarch64 || echo x86_64) \
    && curl -fsSL "https://github.com/helix-editor/helix/releases/download/${HELIX_VERSION}/helix-${HELIX_VERSION}-${ARCH}-linux.tar.xz" | tar -xJ -C /opt \
    && ln -s /opt/helix-${HELIX_VERSION}-${ARCH}-linux/hx /usr/local/bin/hx \
    && ln -s /opt/helix-${HELIX_VERSION}-${ARCH}-linux/runtime /opt/helix-runtime \
    && ARCH2=$([ "$TARGETARCH" = "arm64" ] && echo arm64 || echo amd64) \
    && curl -fsSL "https://releases.hashicorp.com/terraform-ls/${TFLS_VERSION}/terraform-ls_${TFLS_VERSION}_linux_${ARCH2}.zip" -o /tmp/tfls.zip \
    && unzip -qo /tmp/tfls.zip terraform-ls -d /usr/local/bin && rm /tmp/tfls.zip
# archify skill. sbx mounts its shared skills store over ~/.claude/skills, so also run
# `sbx skills import` on the host once (it picks archify up from ~/.claude/skills there).
RUN git clone --depth 1 https://github.com/tt-a1i/archify /tmp/archify-repo \
    && mkdir -p /home/agent/.agents/skills /opt/skills \
    && cp -r /tmp/archify-repo/archify /opt/skills/archify \
    && cp -r /tmp/archify-repo/archify /home/agent/.agents/skills/archify \
    && rm -rf /tmp/archify-repo && chown -R agent:agent /home/agent/.agents
ENV HELIX_RUNTIME=/opt/helix-runtime
USER agent
