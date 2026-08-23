output "ecr_crm_web" {
  value = aws_ecr_repository.crm_web.repository_url
}

output "ecr_crm_backend" {
  value = aws_ecr_repository.crm_backend.repository_url
}

output "ecr_crm_ai" {
  value = aws_ecr_repository.crm_ai.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_deploy.arn
}

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

output "alb_dns_name" {
  description = "Public URL for crm-web once deployed"
  value       = "http://${aws_lb.web.dns_name}"
}

output "database_url" {
  description = "Postgres connection string for crm-backend's DATABASE_URL"
  value       = "postgres://${var.db_username}:${random_password.db.result}@${aws_db_instance.postgres.endpoint}/${var.db_name}"
  sensitive   = true
}
