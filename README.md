# sbx (Docker Sandboxes) flavor — the work-shaped one

    brew install docker/tap/sbx        (Windows: winget install Docker.sbx; Linux: apt install docker-sbx)
    sbx login

Build the template (Docker's official claude-code sandbox image + AWS CLI + Terraform + badge profiles):

    docker build -t sandbox-sbx-claude:latest sbx/claude

Check out a sandbox (microVM, Docker's fence, deny-by-default egress + our allowlist kit):

    sbx run -t sandbox-sbx-claude:latest --kit ./sbx/kit-aws claude                 # RO badge
    sbx run -t sandbox-sbx-claude:latest --kit ./sbx/kit-aws -e AWS_PROFILE=sandbox-rw claude   # RW
    sbx run ... -e CLAUDE_CODE_USE_BEDROCK=1 -e AWS_REGION=us-east-1 claude          # Claude via Bedrock

First AWS call in a fresh sandbox: `aws sso login --use-device-code` (URL + code in your browser).

Differences from the docker-host catalog (`sandbox.sh`):
- sbx launches the agent itself; our entrypoint/badge script is not used — the two profiles are baked instead
- fence = sbx policy (deny-by-default) + kit allowlist, not tinyproxy
- `sbx policy ls` / `sbx policy log` = the audit trail
- template images must extend docker/sandbox-templates:<agent>, user `agent`
