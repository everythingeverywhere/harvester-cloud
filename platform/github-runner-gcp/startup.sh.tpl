#!/usr/bin/env bash
set -euo pipefail

# Installs and registers a GitHub Actions self-hosted runner.
#
# Notes:
# - Runner registration token must exist in Secret Manager as ${github_token_secret_name}
# - Tokens expire; rotate by adding a new secret version.

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y \
  curl \
  jq \
  git \
  ca-certificates \
  apt-transport-https \
  gnupg \
  lsb-release

# Install gcloud to access Secret Manager
if ! command -v gcloud >/dev/null 2>&1; then
  mkdir -p /usr/share/keyrings
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list
  apt-get update -y
  apt-get install -y google-cloud-cli
fi

RUNNER_DIR=/opt/actions-runner
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Pick a pinned runner version for repeatability.
RUNNER_VERSION="2.317.0"
if [[ ! -f "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" ]]; then
  curl -fsSL -o "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
fi

tar xzf "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

# Fetch token from Secret Manager
TOKEN="$(gcloud secrets versions access latest --secret="${github_token_secret_name}")"

# Register runner (idempotency: skip if already configured)
if [[ ! -f .runner ]]; then
  ./config.sh --unattended \
    --url "https://github.com/${github_repo}" \
    --token "$TOKEN" \
    --name "${runner_name}" \
    --labels "${runner_labels}" \
    --work _work
fi

# Install as a service and start
./svc.sh install
./svc.sh start

echo "GitHub runner setup complete"
