# Bootstrap task definitions: just enough to let the ECS services below come up.
# CI (build-and-deploy.yml) registers new revisions under the same family and
# calls update-service on every push — these placeholders are only used once,
# on `terraform apply`, before the first real deploy.

resource "aws_ecs_task_definition" "crm_web_bootstrap" {
  family                   = "crm-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn             = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "crm-web"
      image     = "public.ecr.aws/nginx/nginx:latest"
      essential = true
      portMappings = [{ containerPort = 3000, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.crm_web.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_task_definition" "crm_backend_bootstrap" {
  family                   = "crm-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn             = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "crm-backend"
      image     = "public.ecr.aws/nginx/nginx:latest"
      essential = true
      portMappings = [{ containerPort = 3001, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.crm_backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_task_definition" "crm_ai_bootstrap" {
  family                   = "crm-ai-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn             = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "crm-ai-service"
      image     = "public.ecr.aws/nginx/nginx:latest"
      essential = true
      portMappings = [{ containerPort = 8000, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.crm_ai.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_service" "crm_web" {
  name            = "crm-web-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.crm_web_bootstrap.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.web.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name    = "crm-web"
    container_port    = 3000
  }

  depends_on = [aws_lb_listener.web]

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_ecs_service" "crm_backend" {
  name            = "crm-backend-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.crm_backend_bootstrap.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_ecs_service" "crm_ai" {
  name            = "crm-ai-service-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.crm_ai_bootstrap.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ai.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.ai.arn
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
