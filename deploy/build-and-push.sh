#!/usr/bin/env bash
set -euo pipefail

# Usage: ./build-and-push.sh <aws-account-id> <aws-region>
ACCOUNT_ID=${1:-}
REGION=${2:-}
if [ -z "$ACCOUNT_ID" ] || [ -z "$REGION" ]; then
  echo "Usage: $0 <aws-account-id> <aws-region>" >&2
  exit 2
fi

SERVICES=(crm-web crm-backend crm-ai-service)

for svc in "${SERVICES[@]}"; do
  repo_name="reos/$svc"
  echo "Ensure ECR repo: $repo_name"
  aws ecr describe-repositories --repository-names "$repo_name" --region "$REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$repo_name" --region "$REGION" >/dev/null

  image_tag="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$repo_name:latest"
  echo "Building $svc -> $image_tag"
  docker build -t "$repo_name" "./$svc"

  echo "Tagging and pushing $image_tag"
  aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
  docker tag "$repo_name:latest" "$image_tag"
  docker push "$image_tag"
done

echo "All images pushed."
