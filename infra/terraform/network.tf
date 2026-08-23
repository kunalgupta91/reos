data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "alb" {
  name        = "reos-alb-sg"
  description = "Allow inbound HTTP to the crm-web ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web" {
  name        = "reos-crm-web-sg"
  description = "crm-web Fargate tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "From ALB"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend" {
  name        = "reos-crm-backend-sg"
  description = "crm-backend Fargate tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "From crm-web"
    from_port        = 3001
    to_port          = 3001
    protocol         = "tcp"
    security_groups  = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ai" {
  name        = "reos-crm-ai-service-sg"
  description = "crm-ai-service Fargate tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "From crm-web"
    from_port        = 8000
    to_port          = 8000
    protocol         = "tcp"
    security_groups  = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "reos-rds-sg"
  description = "RDS Postgres for crm-backend"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "From crm-backend"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    security_groups  = [aws_security_group.backend.id]
  }
}
