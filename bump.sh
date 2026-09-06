#!/usr/bin/env bash
# Resolve the current upstream release of each pinned tool and rewrite the ARG lines in place.
#
# The rule is "track latest, but pin the resolved number": the Dockerfiles never say `latest`, so a
# build is always explicit about what it installed, and this script is how those pins move. Run it
# at the start of the monthly rebuild, then rebuild and re-scan both images.
#
# Run this on the host, not inside a sandbox: it reaches checkpoint-api.hashicorp.com and GitHub,
# which the sandbox fence denies by default.
#
#   ./bump.sh            resolve and rewrite the ARG lines
#   ./bump.sh --check    resolve and report only, change nothing
#
# Exit codes: 0 all pins current · 1 (--check only) a pin is behind · 2 an upstream could not be
# reached. 1 and 2 are kept apart on purpose so a GitHub outage does not read as "pins are behind".
set -euo pipefail
cd "$(dirname "$0")"

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

behind=0
failed=0

# stderr is dropped: an unreachable upstream feeds empty input to json.load, and the caller already
# reports that as "could not resolve a version" far more clearly than a traceback would.
json_field() { python3 -c "import sys,json;print(json.load(sys.stdin)$1)" 2>/dev/null; }

latest_hashicorp() {   # <product>
  curl -fsSL --max-time 20 "https://checkpoint-api.hashicorp.com/v1/check/$1" \
    | json_field '["current_version"]'
}

latest_helix() {
  if command -v gh >/dev/null 2>&1 && gh api repos/helix-editor/helix/releases/latest --jq .tag_name 2>/dev/null; then
    return 0
  fi
  curl -fsSL --max-time 20 https://api.github.com/repos/helix-editor/helix/releases/latest \
    | json_field '["tag_name"]'
}

bump() {   # <label> <dockerfile> <ARG name> <resolved version>
  local label=$1 file=$2 arg=$3 new=${4:-} old
  if ! printf '%s' "$new" | grep -qE '^v?[0-9]+(\.[0-9]+)+$'; then
    printf '  %-13s could not resolve a version (got: %s)\n' "$label" "${new:-<empty>}"
    failed=1
    return
  fi
  new=${new#v}
  old=$(grep -E "^ARG ${arg}=" "$file" | head -1 | cut -d= -f2)
  if [ -z "$old" ]; then
    printf '  %-13s no "ARG %s=" line in %s\n' "$label" "$arg" "$file"
    failed=1
    return
  fi
  if [ "$old" = "$new" ]; then
    printf '  %-13s %s (current)\n' "$label" "$old"
    return
  fi
  behind=1
  if [ "$CHECK_ONLY" = 1 ]; then
    printf '  %-13s %s -> %s   BEHIND (%s)\n' "$label" "$old" "$new" "$file"
  else
    sed -i.bak -E "s|^ARG ${arg}=.*|ARG ${arg}=${new}|" "$file"
    rm -f "$file.bak"
    printf '  %-13s %s -> %s   UPDATED (%s)\n' "$label" "$old" "$new" "$file"
  fi
}

echo "Resolving current upstream releases:"
bump "Terraform"    claude/Dockerfile TERRAFORM_VERSION "$(latest_hashicorp terraform    || true)"
bump "terraform-ls" extra/Dockerfile  TFLS_VERSION      "$(latest_hashicorp terraform-ls || true)"
bump "Helix"        extra/Dockerfile  HELIX_VERSION     "$(latest_helix                  || true)"

# npm is pinned deliberately and is NOT tracked to latest. The newest npm refuses the Node the base
# image ships — npm 12 wants node >=22.22.2, Ubuntu 26.04 ships 22.22.1 — and prints an unsupported
# warning on every single invocation. Report the gap so it stays visible; bump NPM_VERSION by hand
# once the image's Node moves past the engine floor.
npm_pinned=$(grep -E '^ARG NPM_VERSION=' claude/Dockerfile | head -1 | cut -d= -f2)
npm_latest=$(curl -fsSL --max-time 20 https://registry.npmjs.org/npm/latest | json_field '["version"]' || true)
if [ -z "$npm_latest" ]; then
  printf '  %-13s %s (pinned; could not reach the registry to check latest)\n' "npm" "$npm_pinned"
  failed=1
elif [ "$npm_pinned" != "$npm_latest" ]; then
  printf '  %-13s %s (held; latest is %s, needs a newer Node than the image ships)\n' \
    "npm" "$npm_pinned" "$npm_latest"
else
  printf '  %-13s %s (current)\n' "npm" "$npm_pinned"
fi

echo
echo "Claude Code is not pinned: the build runs 'claude update', so it picks up the current"
echo "release at build time. Rebuilding is what moves it."
echo
if [ "$failed" = 1 ]; then
  echo "At least one upstream could not be reached — the pins above are unverified, not current."
  exit 2
fi
if [ "$CHECK_ONLY" = 1 ] && [ "$behind" = 1 ]; then
  echo "Pins are behind. Re-run without --check to apply."
  exit 1
fi
echo "Next: docker build --platform linux/arm64 -t claude-base-tools:1.1.0 claude"
echo "      docker build --platform linux/arm64 -t claude-extra-tools:1.1.0 extra"
echo "      docker scout quickview claude-base-tools:1.1.0   # and claude-extra-tools:1.1.0"
