# AWS Deplyoment

Date: 2026-08-21

## Purpose
Record steps taken, findings, and next actions for deploying this repo to AWS (ECR + ECS via GitHub Actions + Terraform).

## What I inspected

- GitHub Actions workflow: [.github/workflows/build-and-deploy.yml](.github/workflows/build-and-deploy.yml#L1)
  - Builds and pushes three images: `crm-web`, `crm-backend`, `crm-ai-service` to ECR under `reos/*`.
  - Uses OIDC role from repository secret `AWS_ROLE_TO_ASSUME` (via `aws-actions/configure-aws-credentials@v2`).
  - Registers ECS task definitions and updates services: `crm-web-service`, `crm-backend-service`, and the AI service name from env `AI_SERVICE`.

- Deploy helper scripts: `deploy/build-and-push.sh`, `deploy/deploy-ecs.sh` (examples/manual helpers).

- Terraform infra: [infra/terraform/main.tf](infra/terraform/main.tf#L1) and related files
  - Creates ECR repos: `reos/crm-web`, `reos/crm-backend`, `reos/crm-ai-service`.
  - Creates ECS cluster (default `reos-cluster`).
  - Creates IAM roles incl. `reos-github-actions-deploy-role` and outputs `github_actions_role_arn`, `ecs_task_execution_role_arn`, `ecs_task_role_arn`.

- Dockerfiles for each service: `crm-web/Dockerfile`, `crm-backend/Dockerfile`, `crm-ai-service/Dockerfile` — all appear buildable.

## Key findings / gaps

- Workflow expects these GitHub repository secrets to be set:
  - `AWS_ROLE_TO_ASSUME` (ARN of OIDC role created by Terraform)
  - `ECS_TASK_EXEC_ROLE` (task execution role ARN)
  - `ECS_TASK_ROLE` (task role ARN)

- Terraform README clearly documents copying `terraform.tfvars.sample` → `terraform.tfvars`, running `terraform init && terraform apply`, and then copying outputs to GitHub secrets.

- The IAM policy attached to the GitHub Actions role is broad (`ecr:*`, `ecs:*`, `iam:PassRole`, `ec2:Describe*` on `*`). Consider tightening for production.

## Steps already done (by me)

1. Reviewed `.github/workflows/build-and-deploy.yml` and confirmed build/push and ECS update flow.
2. Reviewed `infra/terraform` and verified outputs that the workflow uses.
3. Reviewed `deploy/` helper scripts and Dockerfiles.

## Current progress (todo list)

- Create deployment plan: DONE
- Review CI workflow: DONE
- Inspect infra scripts: DONE
- Verify AWS secrets: IN-PROGRESS
- Update workflow & configs: TODO
- Trigger/monitor deploy: TODO
- Run smoke tests: TODO

## Next actions (recommended)

1. Provision infra (run Terraform) from `infra/terraform`:

```bash
cd infra/terraform
cp terraform.tfvars.sample terraform.tfvars   # set aws_account_id, github_owner, github_repo
terraform init
terraform apply
```

2. Copy outputs to GitHub repository secrets (or use `gh`):

```bash
terraform output -json > /tmp/infra-outputs.json
# copy output values to GitHub secrets, e.g. using gh CLI
gh secret set AWS_ROLE_TO_ASSUME --body "$(jq -r .github_actions_role_arn.value /tmp/infra-outputs.json)"
gh secret set ECS_TASK_EXEC_ROLE --body "$(jq -r .ecs_task_execution_role_arn.value /tmp/infra-outputs.json)"
gh secret set ECS_TASK_ROLE --body "$(jq -r .ecs_task_role_arn.value /tmp/infra-outputs.json)"
```

3. Push to `main` (or merge) to trigger the GitHub Actions workflow, or run the workflow manually in GitHub Actions UI.

4. Monitor the workflow run; if images fail to push, ensure OIDC role has ECR permissions and ECR repos exist (Terraform creates them).

5. Run basic smoke tests against newly deployed services (HTTP checks for `crm-web` on configured load balancer / ALB).

## Notes / help I can do next

- I can run `terraform init`/`apply` locally if you provide AWS credentials here (not recommended) or you can run them in your environment.
- I can prepare `gh` CLI commands and a copy-paste checklist to set the GitHub secrets.
- I can tighten the IAM policy for the GitHub Actions role and propose a safer policy.
