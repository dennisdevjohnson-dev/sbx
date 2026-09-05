# sbx template: Docker's official Claude Code sandbox + the AWS toolbelt.
# The agent is launched by sbx itself (not by us); we only add tools + the two badge profiles.
FROM docker/sandbox-templates:claude-code

ARG TERRAFORM_VERSION=1.5.7
ARG TARGETARCH
ARG SSO_START_URL=https://d-90667c720b.awsapps.com/start
ARG SSO_REGION=us-east-1
ARG AWS_ACCOUNT_ID=350823026613

USER root
RUN apt-get update && apt-get install -y --no-install-recommends unzip jq less \
    && rm -rf /var/lib/apt/lists/*
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo aarch64 || echo x86_64) \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o /tmp/awscli.zip \
    && unzip -q /tmp/awscli.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscli.zip
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo arm64 || echo amd64) \
    && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" -o /tmp/tf.zip \
    && unzip -q /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip

# Two badge profiles baked in (no secrets — just where to log in). Pick with AWS_PROFILE=sandbox-ro|sandbox-rw.
USER agent
RUN mkdir -p /home/agent/.aws && cat > /home/agent/.aws/config <<CFG
[sso-session lab]
sso_start_url = ${SSO_START_URL}
sso_region = ${SSO_REGION}
sso_registration_scopes = sso:account:access

[profile sandbox-ro]
sso_session = lab
sso_account_id = ${AWS_ACCOUNT_ID}
sso_role_name = sandbox-ro
region = ${SSO_REGION}

[profile sandbox-rw]
sso_session = lab
sso_account_id = ${AWS_ACCOUNT_ID}
sso_role_name = sandbox-rw
region = ${SSO_REGION}
CFG
ENV AWS_PROFILE=sandbox-ro
