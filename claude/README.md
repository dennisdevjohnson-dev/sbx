# sbx (Docker Sandboxes) flavor — the work-shaped one

    brew install docker/tap/sbx        (Windows: winget install Docker.sbx; Linux: apt install docker-sbx)
    sbx login

Published template (multi-arch: arm64 Macs, amd64 Windows/Linux):

    ghcr.io/dennisdevjohnson-dev/claude-base-tools:v1        # public — no registry login needed
    sbx run -t ghcr.io/dennisdevjohnson-dev/claude-base-tools:v1 --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-fw" --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-aws" claude

Or build it yourself (Docker's official claude-code sandbox image + AWS CLI + Terraform + `aws-badge`). GENERIC: no account values in the image — pass SSO_START_URL / AWS_ACCOUNT_ID at launch and `aws-badge` writes the profiles:

    docker build -t claude-base-tools:latest sbx/claude

Check out a sandbox (microVM, Docker's fence, deny-by-default egress + our allowlist kit):

    sbx run -t claude-base-tools:latest --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-fw" --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-aws" claude                 # RO badge
    sbx run -t claude-base-tools:latest --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-fw" --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-aws" -e AWS_PROFILE=sandbox-rw claude   # RW
    sbx run ... -e CLAUDE_CODE_USE_BEDROCK=1 -e AWS_REGION=us-east-1 claude          # Claude via Bedrock

Fresh machine, nothing but sbx installed (repo + image are public):

    sbx login
    sbx run -t ghcr.io/dennisdevjohnson-dev/claude-base-tools:v1 \
      --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-fw" \
      --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-aws" claude

Prefer to land in bash and start Claude only when you want it? Use the `shell` agent — same image, same kits:

    sbx run -t ghcr.io/dennisdevjohnson-dev/claude-extra-tools:v1 \
      --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-fw" \
      --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-aws" shell

    claude        # start Claude Code from bash;  /exit  drops you back to bash, sandbox stays up
    hx main.tf    # or just use the tools

Pick the model backend yourself:

    sbx run -t claude-base-tools:latest --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-fw" --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-aws" claude
        -> inside, `/login`: 1 Claude.ai account (Max)  2 Anthropic API key  3 Bedrock / Vertex / Foundry
        -> AWS: blank until you give it values. Either pass them at launch:
             -e SSO_START_URL=https://<id>.awsapps.com/start -e AWS_ACCOUNT_ID=<12 digits> -e AWS_PROFILE=sandbox-ro
           or edit ~/.aws/config inside, or run `SSO_START_URL=... AWS_ACCOUNT_ID=... aws-badge` inside.

Or preset Bedrock (no Anthropic key at all) by stacking the add-on kit. Bedrock needs the AWS
badge BEFORE Claude can answer, so log in first on a fresh sandbox:

    sbx create claude --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-fw" --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-aws" --kit "git+https://github.com/dennisdevjohnson-dev/sbx.git#dir=kit-bedrock" -t claude-base-tools:latest --name <name> .
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

    docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/<owner>/claude-base-tools:1.1.0 --push claude
    docker scout quickview claude-base-tools:1.1.0         # local CVE scan (Trivy/Xray say the same)

Work imports the image into Artifactory and Xray scans it there.

## Image hardening (release 1.1.0)

Docker Scout, arm64. `1.1.0` is the same toolset as `v1` — nothing was pinned back, suppressed or
dropped from the image's job.

| Image | v1 | 1.1.0 |
|---|---|---|
| claude-base-tools  |  8C / 106H | **5C / 73H** |
| claude-extra-tools | 19C / 138H | **6C / 77H** |

For scale: Docker's own `docker/sandbox-templates:claude-code` scans 8C / 104H untouched, so v1's
numbers were essentially the template's and our own additions cost +2H. 1.1.0 now scans *below* the
template it is built from.

What changed:

- **`apt-get upgrade -y`** ahead of our installs — picks up the ~41 Ubuntu security updates the
  template layer predates.
- **Purged Ubuntu's `npm`** and the ~340 Debian `node-*` packages it drags in, then restored a
  self-contained upstream npm (`NPM_VERSION`, currently 11.19.1) under `/usr/local`. Ubuntu
  unbundles npm's dependencies into `/usr/share/nodejs`, and *those* libraries carried nearly every
  npm CVE in the report — handlebars, tar, `@babel/traverse`, glob, js-yaml, lodash, postcss,
  nanoid, pacote, browserslist, fast-uri. Nothing in the image used them: Claude Code is a native
  binary, the AWS CLI bundles its own Python, Terraform is a static Go binary. `node`, `git` and
  `curl` are untouched; `npm` and `npx` still work, global installs included.
- **`claude update` at build time** — the template pins whatever Claude Code was current when Docker
  built it (2.1.246); we pull the release current at *our* build (2.1.263) and delete the superseded
  version tree the updater leaves behind.
- **claude-extra-tools only:** `terraform-ls` 0.36.5 → 0.39.0. The old build was compiled with Go
  1.24 and carried `golang.org/x/crypto` 0.39.0 — 7 criticals on its own. That one bump is the
  entire 16C → 6C difference. Helix and archify contribute no findings at all.

What is left, and why it stays:

- **Go stdlib and libraries compiled into vendor binaries** — `stdlib`, `golang.org/x/crypto`,
  `x/mod`, `grpc`, `github.com/docker/cli`, `moby/go-archive`. This is every remaining critical.
  They live inside the Docker CLI that Docker ships in the template, and inside Terraform and
  terraform-ls. Only the upstream vendor can rebuild them; there is no local fix short of dropping
  the tool.
- **`brace-expansion`, `minimatch`, `undici`** (3H / 3H / 5H, no criticals) — these survive the purge
  because the `nodejs` package itself depends on them. Removing them means removing Node.

### Version pins

Nothing says `latest` inside a Dockerfile — every tool is pinned to a resolved release number, so a
build always states exactly what it installed. `./bump.sh` is what moves those pins: it asks each
upstream for its current release, rewrites the `ARG` lines and prints `old -> new` for each.
`./bump.sh --check` reports without touching anything and exits non-zero if a pin is behind, which
is the form to run from cron.

| Tool | Pin | Resolved from |
|---|---|---|
| Terraform    | 1.16.1  | `checkpoint-api.hashicorp.com/v1/check/terraform` |
| terraform-ls | 0.39.0  | `checkpoint-api.hashicorp.com/v1/check/terraform-ls` |
| Helix        | 25.07.1 | `gh api repos/helix-editor/helix/releases/latest` |
| npm          | 11.19.1 | held by hand — see below |
| Claude Code  | not pinned | `claude update` runs at build time (2.1.263 in this build) |

All of these were the current upstream release as of 2026-09-06. npm is the one deliberate exception
to "track latest": npm 12 requires Node >= 22.22.2 and Ubuntu 26.04 ships 22.22.1, so it prints an
unsupported-version warning on every single invocation. `bump.sh` reports that gap but will not
apply it — bump `NPM_VERSION` by hand once the image's Node moves past the floor.

**Rule: rebuild monthly.** Both Dockerfiles deliberately track moving targets — `apt-get upgrade`,
`claude update`, and Docker's own template underneath. Rebuilding is how upstream fixes reach you;
a stale image only ever gets worse. So: `./bump.sh`, rebuild both images, smoke-test, re-scan.
Terraform is worth watching in particular — the old 1.5.7 pin carried ~15 criticals via Go 1.20-era
libs.

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

## Hacking on the kits locally

From a checkout of this repo, `--kit ./kit-fw --kit ./kit-aws` uses your working copy instead of the
published one. Validate a kit with `sbx kit pack kit-fw -o /dev/null`.
