#!/usr/bin/env bash
set -euo pipefail

# Manage Lab Factory metadata in the TF state bucket.
#
# This script is intended for CI use.
# Requirements:
# - gcloud authenticated
# - gsutil available
#
# Env vars:
# - TF_STATE_BUCKET (required)
# - TF_STATE_PREFIX (optional; default: harvester-cloud/gcp)

TF_STATE_PREFIX="${TF_STATE_PREFIX:-harvester-cloud/gcp}"

usage() {
  cat <<EOF
Usage:
  lab_meta.sh write   --lab-id <id> --owner <email> --ttl-hours <n> [--notes <text>]
  lab_meta.sh extend  --lab-id <id> --ttl-hours <n>
  lab_meta.sh read    --lab-id <id>
  lab_meta.sh delete  --lab-id <id>

Writes metadata to:
  gs://$TF_STATE_BUCKET/$TF_STATE_PREFIX/labs/<lab_id>/meta.json
EOF
}

require_env() {
  local v="$1"
  if [[ -z "${!v:-}" ]]; then
    echo "ERROR: env var $v is required" >&2
    exit 1
  fi
}

rfc3339_now() {
  # GNU date is available on ubuntu-latest
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

rfc3339_plus_hours() {
  local hours="$1"
  date -u -d "+${hours} hour" +"%Y-%m-%dT%H:%M:%SZ"
}

cmd="${1:-}"
shift || true

lab_id=""
owner=""
ttl_hours=""
notes=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lab-id) lab_id="$2"; shift 2;;
    --owner) owner="$2"; shift 2;;
    --ttl-hours) ttl_hours="$2"; shift 2;;
    --notes) notes="$2"; shift 2;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

require_env TF_STATE_BUCKET
if [[ -z "$lab_id" ]]; then
  echo "ERROR: --lab-id is required" >&2
  usage
  exit 2
fi

meta_path="${TF_STATE_PREFIX}/labs/${lab_id}/meta.json"
meta_gs="gs://${TF_STATE_BUCKET}/${meta_path}"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

case "$cmd" in
  write)
    if [[ -z "$owner" || -z "$ttl_hours" ]]; then
      echo "ERROR: write requires --owner and --ttl-hours" >&2
      usage
      exit 2
    fi
    created_at="$(rfc3339_now)"
    expires_at="$(rfc3339_plus_hours "$ttl_hours")"
    cat >"$tmp" <<JSON
{
  "lab_id": "${lab_id}",
  "owner": "${owner}",
  "created_at": "${created_at}",
  "expires_at": "${expires_at}",
  "notes": "${notes//\"/\\\"}"
}
JSON
    gsutil -q cp "$tmp" "$meta_gs"
    echo "Wrote $meta_gs"
    ;;

  extend)
    if [[ -z "$ttl_hours" ]]; then
      echo "ERROR: extend requires --ttl-hours" >&2
      usage
      exit 2
    fi
    # read existing
    gsutil -q cp "$meta_gs" "$tmp" || { echo "ERROR: meta not found: $meta_gs" >&2; exit 1; }
    expires_at="$(rfc3339_plus_hours "$ttl_hours")"
    # minimal JSON edit w/ sed: replace expires_at value
    # (safe enough for our simple file)
    sed -i -E "s/\"expires_at\"\s*:\s*\"[^\"]+\"/\"expires_at\": \"${expires_at}\"/" "$tmp"
    gsutil -q cp "$tmp" "$meta_gs"
    echo "Extended $meta_gs to expires_at=${expires_at}"
    ;;

  read)
    gsutil cat "$meta_gs"
    ;;

  delete)
    gsutil -q rm -f "$meta_gs" || true
    echo "Deleted $meta_gs (if existed)"
    ;;

  *)
    echo "ERROR: unknown command: $cmd" >&2
    usage
    exit 2
    ;;
esac
