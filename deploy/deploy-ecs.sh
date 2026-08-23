#!/usr/bin/env bash
set -euo pipefail

# Example: register a task definition and create an ECS service (manual steps)
# Edit the placeholders below and run.

CLUSTER_NAME="reos-cluster"
SERVICE_NAME="reos-{{service}}"
TASK_FAMILY="reos-{{service}}-task"
REGION=${AWS_REGION:-us-east-1}
ACCOUNT_ID=${AWS_ACCOUNT_ID:-}

echo "This script contains example AWS CLI commands to register a task and create a service."
echo "Adjust JSON task definitions and networking settings before running."

cat <<'EOF'
# Example to register a task (replace placeholders and provide container definitions JSON)
aws ecs register-task-definition \
  --cli-input-json file://task-def-{{service}}.json \
  --region ${REGION}

# Example to create a service
aws ecs create-service \
  --cluster ${CLUSTER_NAME} \
  --service-name ${SERVICE_NAME} \
  --task-definition ${TASK_FAMILY} \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-...],securityGroups=[sg-...],assignPublicIp=ENABLED}" \
  --region ${REGION}
EOF
