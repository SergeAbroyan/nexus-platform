locals {
  application_namespace = "nexus"
  storage_class_name    = "nexus-gp3"

  ingress_gateway = {
    name      = "istio-ingress"
    namespace = "istio-ingress"
    selector  = { istio = "ingress" }
  }

  trace_gateway = {
    name      = "otel-traces"
    namespace = "monitoring"
    port      = 4317
  }
  trace_gateway_host = "${local.trace_gateway.name}.${local.trace_gateway.namespace}.svc.cluster.local"

  service_accounts = {
    load_balancer_controller = { namespace = "kube-system", name = "aws-load-balancer-controller" }
    external_secrets         = { namespace = "external-secrets", name = "external-secrets" }
    alertmanager             = { namespace = "monitoring", name = "alertmanager" }
    grafana                  = { namespace = "monitoring", name = "grafana" }
    api                      = { namespace = local.application_namespace, name = "api" }
    worker                   = { namespace = local.application_namespace, name = "worker" }
  }
}
