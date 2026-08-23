Deployment notes — ECR + ECS Fargate

This folder contains helper scripts and instructions to build images, push
them to Amazon ECR, and deploy to ECS Fargate. It assumes you have the
`aws` CLI configured and `docker` available locally.

High-level steps:
1. Create ECR repositories for each service (or let the script create them).
2. Build Docker images and tag them for ECR.
3. Push images to ECR.
4. Create ECS cluster, task definitions, and services (Fargate); configure
   an Application Load Balancer and security groups.

See `build-and-push.sh` for automated push and `deploy-ecs.sh` for example
commands to register a task and create a service. Edit variables at the top
of the scripts to match your AWS account and region.
