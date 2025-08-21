# Timesketch Module
# This module manages the Timesketch Helm chart deployment via OSDFIR infrastructure chart

# Install Timesketch via OSDFIR Helm chart with billing labels
resource "helm_release" "osdfir" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://google.github.io/osdfir-infrastructure/"
  chart      = "osdfir-infrastructure"
  version    = "2.4.0"
  values     = [file("${path.root}/../helm/osdfir-production-values.yaml")]
  replace    = true
  timeout    = 900 # 15 minutes
  
  set {
    name  = "timesketch.config.existingConfigMap"
    value = var.timesketch_config_map_name
  }
  
  set {
    name  = "global.labels.billing-code"
    value = var.billing_labels["billing-code"]
  }
  
  set {
    name  = "global.labels.environment"
    value = var.billing_labels["environment"]
  }
  
  set {
    name  = "global.labels.project"
    value = "osdfir"
  }
  
  set {
    name  = "global.labels.component"
    value = "osdfir-platform"
  }
  
  set {
    name  = "global.labels.cost-center"
    value = var.billing_labels["cost-center"]
  }
  
  set {
    name  = "global.labels.owner"
    value = var.billing_labels["owner"]
  }
  
  # Explicitly enable Timesketch and disable other components
  set {
    name  = "global.timesketch.enabled"
    value = "true"
  }
  
  set {
    name  = "global.openrelik.enabled"
    value = "false"  # Explicitly disable OpenRelik component
  }
  
  set {
    name  = "global.yeti.enabled"
    value = "false"
  }
}