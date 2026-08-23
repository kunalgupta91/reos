Terraform infra for ECR + ECS + IAM (GitHub OIDC)

Quick start

1. Copy the sample vars and edit values:

```bash
cp terraform.tfvars.sample terraform.tfvars
# edit terraform.tfvars and set github_owner/github_repo to your repository
```

2. Initialize and apply (interactive):

```bash
cd infra/terraform
terraform init
terraform apply
```

3. After apply completes, note outputs (or run `terraform output -json`):

```bash
terraform output
```

You need to copy the value of `github_actions_role_arn` into your GitHub repository secret named `AWS_ROLE_TO_ASSUME`.

Also add these repository secrets (values from Terraform outputs):

- `ECS_TASK_EXEC_ROLE` = `ecs_task_execution_role_arn`
- `ECS_TASK_ROLE` = `ecs_task_role_arn`

If you prefer using the AWS Console or `gh` CLI to create the secret, paste the role ARN there.

Notes
- The Terraform configuration creates:
  - ECR repositories: `reos/crm-web`, `reos/crm-backend`, `reos/crm-ai-service`
  - ECS cluster: default `reos-cluster` (change via `cluster_name`)
  - IAM roles: task execution role, task role, and a GitHub Actions OIDC deploy role

- The GitHub Actions workflow assumes the OIDC role (set in `AWS_ROLE_TO_ASSUME`) and will perform ECR/ECS operations.

Security
- The OIDC flow avoids long-lived AWS keys in GitHub. The role created has broad permissions for simplicity; consider tightening policies before using in production.
