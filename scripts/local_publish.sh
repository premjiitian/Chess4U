#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# local_publish.sh  –  Build & submit Chess4U to the App Store from your Mac.
#
# Run once to initialise signing, then again for every release.
# No GitHub Actions credits required.
#
# Usage:
#   chmod +x scripts/local_publish.sh
#   ./scripts/local_publish.sh
#
# Or to skip interactive prompts, copy .env.example → .env and fill it in:
#   cp scripts/.env.example scripts/.env
#   ./scripts/local_publish.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# ── Colour helpers ────────────────────────────────────────────────────────────
bold=$'\033[1m'; red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'; reset=$'\033[0m'
info()    { echo "${bold}[info]${reset} $*"; }
success() { echo "${green}[ok]${reset}   $*"; }
warn()    { echo "${yellow}[warn]${reset} $*"; }
die()     { echo "${red}[error]${reset} $*" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────────────
info "Checking prerequisites…"
command -v ruby   >/dev/null || die "ruby not found. Install via rbenv or Homebrew."
command -v bundle >/dev/null || die "bundler not found. Run: gem install bundler"
xcodebuild -version >/dev/null 2>&1 || die "Xcode not found. Install from the Mac App Store."
command -v git >/dev/null || die "git not found."
success "Prerequisites OK"

# ── Load secrets ──────────────────────────────────────────────────────────────
if [[ -f "$ENV_FILE" ]]; then
  info "Loading secrets from scripts/.env"
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi

prompt_if_empty() {
  local var="$1" prompt="$2" secret="${3:-false}"
  if [[ -z "${!var:-}" ]]; then
    if [[ "$secret" == "true" ]]; then
      read -r -s -p "${bold}${prompt}:${reset} " "$var"; echo
    else
      read -r -p "${bold}${prompt}:${reset} " "$var"
    fi
    export "${var?}"
  fi
}

echo
echo "${bold}Enter the secrets below (press Enter to skip if already set via .env):${reset}"
echo "  Tip: copy values from your GitHub repo → Settings → Secrets"
echo
prompt_if_empty MATCH_GIT_URL                   "MATCH_GIT_URL  (e.g. https://github.com/you/chess4u-certs)"
prompt_if_empty MATCH_PASSWORD                  "MATCH_PASSWORD (encryption passphrase for the certs repo)" true
prompt_if_empty GH_PAT                          "GH_PAT         (GitHub Personal Access Token with repo scope)" true
prompt_if_empty DEVELOPMENT_TEAM               "DEVELOPMENT_TEAM (10-char Apple team ID, e.g. AB12CD34EF)"
prompt_if_empty APP_STORE_CONNECT_API_KEY_ID   "API_KEY_ID     (App Store Connect API key ID)"
prompt_if_empty APP_STORE_CONNECT_ISSUER_ID    "ISSUER_ID      (App Store Connect issuer UUID)"
prompt_if_empty APP_STORE_CONNECT_API_KEY_BASE64 "API_KEY_BASE64 (base64-encoded .p8 key content)" true
echo

# ── Normalise the API key to base64(PKCS#8 PEM) ───────────────────────────────
info "Normalising App Store Connect API key…"
APP_STORE_CONNECT_API_KEY_BASE64=$(python3 - <<'PYEOF'
import base64, os, sys
from cryptography.hazmat.primitives import serialization
raw = os.environ.get('APP_STORE_CONNECT_API_KEY_BASE64', '')
if not raw:
    print('[key-norm] APP_STORE_CONNECT_API_KEY_BASE64 is not set', file=sys.stderr)
    sys.exit(1)
candidates = []
try:
    stripped = ''.join(raw.split())
    candidates.append(base64.b64decode(stripped, validate=True))
except Exception:
    pass
candidates.append(raw.encode())
for i, data in enumerate(candidates):
    try:
        key = serialization.load_pem_private_key(data, password=None)
        pem = key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption())
        print(base64.b64encode(pem).decode(), end='')
        sys.exit(0)
    except Exception as e:
        print('[key-norm] attempt ' + str(i) + ' failed: ' + str(e), file=sys.stderr)
print('[key-norm] could not load key in any format', file=sys.stderr)
sys.exit(1)
PYEOF
)
export APP_STORE_CONNECT_API_KEY_BASE64
success "API key normalised"

# ── Git identity (match needs to push to the certs repo) ─────────────────────
git config --global user.email "ci@chess4u.app" 2>/dev/null || true
git config --global user.name  "Chess4U CI"     2>/dev/null || true

# ── Choose what to do ─────────────────────────────────────────────────────────
cd "$REPO_ROOT"
bundle install --quiet

echo
echo "${bold}What would you like to do?${reset}"
echo "  1) Initialise signing certificates (run once, or to rotate certs)"
echo "  2) Build & upload to TestFlight   (requires certs from step 1)"
echo "  3) Both (init then upload)"
echo
read -r -p "${bold}Choice [1/2/3]:${reset} " CHOICE

case "$CHOICE" in
  1)
    info "Running fastlane init_match…"
    bundle exec fastlane init_match
    success "Certificates pushed to $MATCH_GIT_URL"
    echo
    echo "Next step: run this script again and choose option 2 to upload to TestFlight."
    ;;
  2)
    prompt_if_empty VERSION "Version number (e.g. 1.0.0)"
    export VERSION
    info "Running fastlane beta (version $VERSION)…"
    bundle exec fastlane beta
    success "Build uploaded to TestFlight!"
    echo
    echo "Next step: go to App Store Connect → TestFlight and distribute the build to"
    echo "external testers, then run option to submit for review when ready."
    ;;
  3)
    info "Initialising certificates…"
    bundle exec fastlane init_match
    success "Certificates ready."
    echo
    prompt_if_empty VERSION "Version number (e.g. 1.0.0)"
    export VERSION
    info "Building & uploading to TestFlight (version $VERSION)…"
    bundle exec fastlane beta
    success "Done! Build uploaded to TestFlight."
    ;;
  *)
    die "Unknown choice '$CHOICE'. Run the script again."
    ;;
esac
