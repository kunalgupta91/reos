variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_account_id" {
  description = "AWS account id"
  type        = string
}

variable "github_owner" {
  description = "GitHub owner/org for the repository that will use OIDC"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name that will use OIDC"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "reos-cluster"
}

variable "db_name" {
  description = "RDS Postgres database name"
  type        = string
  default     = "reos"
}

variable "db_username" {
  description = "RDS Postgres master username"
  type        = string
  default     = "reos_app_user"
}
