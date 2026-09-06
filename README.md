# sbx (Docker Sandboxes) flavor — the work-shaped one

    brew install docker/tap/sbx        (Windows: winget install Docker.sbx; Linux: apt install docker-sbx)
    sbx login

Published template (multi-arch: arm64 Macs, amd64 Windows/Linux):

    ghcr.io/dennisdevjohnson-dev/claude-base-tools:v1        # public — no registry login needed
    sbx run -t ghcr.io/dennisdevjohnson-dev/claude-base-tools:v1 --kit ./kit-fw --kit ./kit-aws claude

Or build it yourself (Docker's official claude-code sandbox image + AWS CLI + Terraform + `aws-badge`). GENERIC: no account values in the image — pass SSO_START_URL / AWS_ACCOUNT_ID at launch and `aws-badge` writes the profiles:

    docker build -t claude-base-tools:latest sbx/claude

Check out a sandbox (microVM, Docker's fence, deny-by-default egress + our allowlist kit):

    sbx run -t claude-base-tools:latest --kit ./sbx/kit-fw --kit ./sbx/kit-aws claude                 # RO badge
    sbx run -t claude-base-tools:latest --kit ./sbx/kit-fw --kit ./sbx/kit-aws -e AWS_PROFILE=sandbox-rw claude   # RW
    sbx run ... -e CLAUDE_CODE_USE_BEDROCK=1 -e AWS_REGION=us-east-1 claude          # Claude via Bedrock

Fresh machine, nothing but sbx installed (repo + image are public):

    sbx login
    sbx run -t ghcr.io/dennisdevjohnson-dev/claude-base-tools:v1 \
      --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-fw" \
      --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-aws" claude

Pick the model backend yourself:

    sbx run -t claude-base-tools:latest --kit ./sbx/kit-fw --kit ./sbx/kit-aws claude
        -> inside, `/login`: 1 Claude.ai account (Max)  2 Anthropic API key  3 Bedrock / Vertex / Foundry
        -> AWS: blank until you give it values. Either pass them at launch:
             -e SSO_START_URL=https://<id>.awsapps.com/start -e AWS_ACCOUNT_ID=<12 digits> -e AWS_PROFILE=sandbox-ro
           or edit ~/.aws/config inside, or run `SSO_START_URL=... AWS_ACCOUNT_ID=... aws-badge` inside.

Or preset Bedrock (no Anthropic key at all) by stacking the add-on kit. Bedrock needs the AWS
badge BEFORE Claude can answer, so log in first on a fresh sandbox:

    sbx create claude --kit ./sbx/kit-fw --kit ./sbx/kit-aws --kit ./sbx/kit-bedrock -t claude-base-tools:latest --name <name> .
    sbx exec <name> -- aws sso login --use-device-code      # URL + code in your browser (~8h)
    sbx run <name>

Kits: kit-fw = the fence (allowlist) · kit-aws = badge writer + AWS guidance · kit-bedrock = Bedrock preset. Stack what you need.
Codex / other agents: same kits, their own login.

Differences from the docker-host catalog (`sandbox.sh`):
- sbx launches the agent itself; the kit's startup command runs `aws-badge`, which writes the two SSO profiles from env
- fence = sbx policy (deny-by-default) + kit allowlist, not tinyproxy
- `sbx policy ls` / `sbx policy log` = the audit trail
- template images must extend docker/sandbox-templates:<agent>, user `agent`

## Bedrock via a profile (persistent, no /login menu)

Two files inside the sandbox. `aws-badge` writes the first if you give it values.

`~/.aws/config` — an ordinary AWS profile (SSO or keys); nothing Bedrock-specific:

    [sso-session lab]
    sso_start_url = https://<id>.awsapps.com/start
    sso_region = us-east-1
    sso_registration_scopes = sso:account:access

    [profile bedrock]
    sso_session = lab
    sso_account_id = <12 digits>
    sso_role_name = <permission set>      # must allow bedrock:InvokeModel*
    region = us-east-1

`~/.claude/settings.json` — point Claude Code at it:

    {
      "env": {
        "CLAUDE_CODE_USE_BEDROCK": "1",
        "AWS_PROFILE": "bedrock",
        "AWS_REGION": "us-east-1",
        "ANTHROPIC_MODEL": "us.anthropic.claude-sonnet-4-6"
      },
      "awsAuthRefresh": "aws sso login --profile bedrock --use-device-code"
    }

`awsAuthRefresh` = what Claude runs itself when the SSO token expires. Model IDs must be
ones enabled in the account (`aws bedrock list-inference-profiles`); the newest (Sonnet 5 /
Opus 5) are sales-gated on personal accounts. Same thing as env vars: `-e CLAUDE_CODE_USE_BEDROCK=1 ...`
at launch, or the kit-bedrock add-on.

Inside any sandbox: `cat /etc/sandbox/README.md`

## Publish + scan

    docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/<owner>/claude-base-tools:v1 --push claude
    docker scout quickview claude-base-tools:latest        # local CVE scan (Trivy/Xray say the same)

Scout on v1: 8 critical / 106 high — Docker's base template alone is 5C / 77H; ours adds AWS CLI's bundled
Python deps. Terraform is pinned to the current release (1.5.7 carried ~15 criticals via Go 1.20-era libs).
Work imports the image into Artifactory and Xray scans it there.

## claude-extra-tools (home flavor)

    ghcr.io/dennisdevjohnson-dev/claude-extra-tools:v1   = claude-base-tools + Helix (hx) + terraform-ls + archify

Same kits, same run line with `-t …/claude-extra-tools:v1`. archify note: sbx mounts a shared
skills store over `~/.claude/skills` inside sandboxes, so on the host run `sbx skills import`
once (it copies archify from your `~/.claude/skills`); the image also carries it at /opt/skills/archify.

Build note for claude-extra-tools: the Helix tarball fails under amd64 *emulation* on Apple Silicon
(`tar: Cannot mkdir: Function not implemented` — Ubuntu 26.04 syscalls vs the emulator). Build each
arch natively and stitch:

    # Mac (arm64)            docker buildx build --platform linux/arm64 -t <repo>:v1-arm64 --push extra
    # any x86_64 Linux box   docker buildx build --platform linux/amd64 -t <repo>:v1-amd64 --push extra
    docker buildx imagetools create -t <repo>:v1 <repo>:v1-arm64 <repo>:v1-amd64
