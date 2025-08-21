# Kubernetes Module
# This module manages Kubernetes resources

# Create the OSDFIR namespace with billing labels
resource "kubernetes_namespace" "osdfir" {
  metadata {
    name = var.namespace
    labels = merge(var.billing_labels, {
      component = "kubernetes-namespace"
      usage = "timesketch-platform"
    })
  }
  
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

# Custom storage class for NFS (ReadWriteMany)
resource "kubernetes_storage_class" "nfs_rwx" {
  metadata {
    name = "nfs-rwx"
    labels = merge(var.billing_labels, {
      component = "storage-class"
      storage-type = "nfs"
    })
  }

  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "Immediate"
  reclaim_policy      = "Retain"
  
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

# PersistentVolume for global Filestore
resource "kubernetes_persistent_volume" "osdfirvolume" {
  metadata {
    name = "osdfirvolume"
    labels = merge(var.billing_labels, {
      component = "persistent-volume"
      storage-type = "nfs"
      usage = "shared-storage"
    })
  }

  spec {
    storage_class_name               = kubernetes_storage_class.nfs_rwx.metadata[0].name
    capacity = {
      storage = "${var.filestore_capacity_gb}Gi"
    }
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      nfs {
        server = var.filestore_ip_address
        path   = "/vol1"
      }
    }
  }
  
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

# PVC bound to the Filestore PV
resource "kubernetes_persistent_volume_claim" "osdfirvolume" {
  metadata {
    name      = "osdfirvolume"
    namespace = var.namespace
    labels = merge(var.billing_labels, {
      component = "persistent-volume-claim"
      storage-type = "nfs"
      usage = "shared-storage"
    })
  }

  spec {
    storage_class_name = kubernetes_storage_class.nfs_rwx.metadata[0].name
    access_modes       = ["ReadWriteMany"]
    volume_name        = kubernetes_persistent_volume.osdfirvolume.metadata[0].name

    resources {
      requests = {
        storage = "${var.filestore_capacity_gb}Gi"
      }
    }
  }

  depends_on = [kubernetes_namespace.osdfir]
  
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

# Create tar.gz archive of Timesketch data directory
resource "null_resource" "timesketch_configs" {
  triggers = {
    data_dir_hash = var.timesketch_configs_hash
  }

  provisioner "local-exec" {
    command     = "cd ${path.root}/../configs/data; tar -czf ${path.root}/ts-configs.tar.gz ."
    interpreter = ["powershell", "-Command"]
  }
}

# Read the created tar.gz file
data "local_file" "timesketch_configs_tar" {
  filename   = "${path.root}/ts-configs.tar.gz"
  depends_on = [null_resource.timesketch_configs]
}

# Create ConfigMap with base64 encoded tarball
resource "kubernetes_config_map" "timesketch_configs" {
  metadata {
    name      = "${var.release_name}-timesketch-configs"
    namespace = kubernetes_namespace.osdfir.metadata[0].name
    labels = merge(var.billing_labels, {
      component = "config-map"
      usage = "timesketch-configs"
    })
  }

  data = {
    "ts-configs.tgz.b64" = data.local_file.timesketch_configs_tar.content_base64
  }
  
  depends_on = [
    kubernetes_namespace.osdfir,
    null_resource.timesketch_configs
  ]
  
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

# Horizontal Pod Autoscalers
resource "kubernetes_horizontal_pod_autoscaler" "timesketch_worker" {
  metadata {
    name      = "timesketch-worker-hpa"
    namespace = kubernetes_namespace.osdfir.metadata[0].name
    labels = merge(var.billing_labels, {
      component = "horizontal-pod-autoscaler"
      workload  = "timesketch-worker"
    })
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "osdfir-timesketch-worker"
    }

    min_replicas = 1
    max_replicas = 4

    target_cpu_utilization_percentage = 80
  }
  
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}