terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "crm_web" {
  name = "reos/crm-web"
}

resource "aws_ecr_repository" "crm_backend" {
  name = "reos/crm-backend"
}

resource "aws_ecr_repository" "crm_ai" {
  name = "reos/crm-ai-service"
}

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
}
