#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/bootstrap-oidc.sh --repo <owner/repo> [options]

Required:
  --repo                 GitHub repository in owner/repo format

Options:
  --branch               Branch to allow in trust policy (default: main)
  --role-name            IAM role name (default: github-actions-terraform-prod)
  --policy-name          Inline policy name (default: terraform-prod-policy)
  --policy-file          Policy JSON file path (default: .github/iam/terraform-prod-policy.json)
  --account-id           AWS account id (default: autodetect via sts)
  --profile              AWS CLI profile name
  --allow-pull-request   Allow repo:<owner/repo>:pull_request subject (default: true)
  -h, --help             Show this help
EOF
}

REPO=""
BRANCH="main"
ROLE_NAME="github-actions-terraform-prod"
POLICY_NAME="terraform-prod-policy"
POLICY_FILE=".github/iam/terraform-prod-policy.json"
ACCOUNT_ID=""
PROFILE=""
ALLOW_PULL_REQUEST="true"
OIDC_URL="https://token.actions.githubusercontent.com"
OIDC_HOST="token.actions.githubusercontent.com"
OIDC_AUDIENCE="sts.amazonaws.com"
OIDC_THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"; shift 2 ;;
    --branch)
      BRANCH="${2:-}"; shift 2 ;;
    --role-name)
      ROLE_NAME="${2:-}"; shift 2 ;;
    --policy-name)
      POLICY_NAME="${2:-}"; shift 2 ;;
    --policy-file)
      POLICY_FILE="${2:-}"; shift 2 ;;
    --account-id)
      ACCOUNT_ID="${2:-}"; shift 2 ;;
    --profile)
      PROFILE="${2:-}"; shift 2 ;;
    --allow-pull-request)
      ALLOW_PULL_REQUEST="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "$REPO" ]]; then
  echo "--repo is required" >&2
  usage
  exit 1
fi

if [[ ! -f "$POLICY_FILE" ]]; then
  echo "Policy file not found: $POLICY_FILE" >&2
  exit 1
fi

AWS_ARGS=()
if [[ -n "$PROFILE" ]]; then
  AWS_ARGS+=(--profile "$PROFILE")
fi

if [[ -z "$ACCOUNT_ID" ]]; then
  ACCOUNT_ID="$(aws sts get-caller-identity "${AWS_ARGS[@]}" --query 'Account' --output text)"
fi

OIDC_ARN=""
for arn in $(aws iam list-open-id-connect-providers "${AWS_ARGS[@]}" --query 'OpenIDConnectProviderList[].Arn' --output text); do
  url="$(aws iam get-open-id-connect-provider "${AWS_ARGS[@]}" --open-id-connect-provider-arn "$arn" --query 'Url' --output text)"
  if [[ "$url" == "$OIDC_HOST" ]]; then
    OIDC_ARN="$arn"
    break
  fi
done

if [[ -z "$OIDC_ARN" ]]; then
  echo "Creating GitHub OIDC provider..."
  OIDC_ARN="$(aws iam create-open-id-connect-provider \
    "${AWS_ARGS[@]}" \
    --url "$OIDC_URL" \
    --client-id-list "$OIDC_AUDIENCE" \
    --thumbprint-list "$OIDC_THUMBPRINT" \
    --query 'OpenIDConnectProviderArn' \
    --output text)"
else
  echo "OIDC provider already exists: $OIDC_ARN"
fi

TRUST_FILE="$(mktemp)"
cleanup() { rm -f "$TRUST_FILE"; }
trap cleanup EXIT

if [[ "$ALLOW_PULL_REQUEST" == "true" ]]; then
  SUB_BLOCK=$(cat <<EOF
[
  "repo:${REPO}:ref:refs/heads/${BRANCH}",
  "repo:${REPO}:pull_request"
]
EOF
)
else
  SUB_BLOCK=$(cat <<EOF
"repo:${REPO}:ref:refs/heads/${BRANCH}"
EOF
)
fi

cat > "$TRUST_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_HOST}:aud": "${OIDC_AUDIENCE}"
        },
        "StringLike": {
          "${OIDC_HOST}:sub": ${SUB_BLOCK}
        }
      }
    }
  ]
}
EOF

if aws iam get-role "${AWS_ARGS[@]}" --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Updating trust policy for role: $ROLE_NAME"
  aws iam update-assume-role-policy "${AWS_ARGS[@]}" \
    --role-name "$ROLE_NAME" \
    --policy-document "file://${TRUST_FILE}"
else
  echo "Creating role: $ROLE_NAME"
  aws iam create-role "${AWS_ARGS[@]}" \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://${TRUST_FILE}" >/dev/null
fi

echo "Applying inline policy: $POLICY_NAME"
aws iam put-role-policy "${AWS_ARGS[@]}" \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "file://${POLICY_FILE}"

ROLE_ARN="$(aws iam get-role "${AWS_ARGS[@]}" --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)"
echo "Done."
echo "Role ARN: $ROLE_ARN"
echo "Set this in GitHub repository secret: AWS_GITHUB_OIDC_ROLE_ARN"
