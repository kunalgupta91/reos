resource "aws_cloudwatch_log_group" "crm_web" {
  name              = "/ecs/crm-web"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "crm_backend" {
  name              = "/ecs/crm-backend"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "crm_ai" {
  name              = "/ecs/crm-ai-service"
  retention_in_days = 14
}
