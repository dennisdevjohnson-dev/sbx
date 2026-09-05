# sbx (Docker Sandboxes) flavor — the work-shaped one

    brew install docker/tap/sbx        (Windows: winget install Docker.sbx; Linux: apt install docker-sbx)
    sbx login

Build the template (Docker's official claude-code sandbox image + AWS CLI + Terraform + `aws-badge`). GENERIC: no account values in the image — the kit supplies SSO_START_URL / AWS_ACCOUNT_ID and runs `aws-badge` at start:

    docker build -t claude-base-tools:latest sbx/claude

Check out a sandbox (microVM, Docker's fence, deny-by-default egress + our allowlist kit):

    sbx run -t claude-base-tools:latest --kit ./sbx/kit-aws claude                 # RO badge
    sbx run -t claude-base-tools:latest --kit ./sbx/kit-aws -e AWS_PROFILE=sandbox-rw claude   # RW
    sbx run ... -e CLAUDE_CODE_USE_BEDROCK=1 -e AWS_REGION=us-east-1 claude          # Claude via Bedrock

Pick the model backend yourself:

    sbx run -t claude-base-tools:latest --kit ./sbx/kit-aws claude
        -> inside, `/login`: 1 Claude.ai account (Max)  2 Anthropic API key  3 Bedrock / Vertex / Foundry

Or preset Bedrock (no Anthropic key at all) by stacking the add-on kit. Bedrock needs the AWS
badge BEFORE Claude can answer, so log in first on a fresh sandbox:

    sbx create claude --kit ./sbx/kit-aws --kit ./sbx/kit-bedrock -t claude-base-tools:latest --name <name> .
    sbx exec <name> -- aws sso login --use-device-code      # URL + code in your browser (~8h)
    sbx run <name>

Codex / other agents: same kit-aws, their own login.

Differences from the docker-host catalog (`sandbox.sh`):
- sbx launches the agent itself; the kit's startup command runs `aws-badge`, which writes the two SSO profiles from env
- fence = sbx policy (deny-by-default) + kit allowlist, not tinyproxy
- `sbx policy ls` / `sbx policy log` = the audit trail
- template images must extend docker/sandbox-templates:<agent>, user `agent`
