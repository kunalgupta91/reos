resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "reos.local"
  vpc  = data.aws_vpc.default.id
}

resource "aws_service_discovery_service" "backend" {
  name = "crm-backend"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_service_discovery_service" "ai" {
  name = "crm-ai-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}
