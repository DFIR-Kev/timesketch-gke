# OSDFIR Infrastructure Terraform - Modular Architecture

This directory contains the Terraform configuration for deploying the OSDFIR (Open Source Digital Forensics and Incident Response) infrastructure on Google Cloud Platform using a modular architecture.

## Directory Structure

```
terraform/
├── main-modular.tf          # New modular main configuration
├── outputs-modular.tf       # New modular outputs
├── variables.tf             # Input variables (unchanged)
├── openrelik-importer.tf    # Original OpenRelik importer (legacy)
├── main.tf                  # Original monolithic configuration (legacy)
├── outputs.tf               # Original monolithic outputs (legacy)
├── modules/                 # Terraform modules
│   ├── gke/                # GKE cluster and node pools
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/            # Filestore and GCS bucket
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── networking/         # VPC, NAT, firewall rules
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── iam/               # Service accounts and permissions
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── pubsub/            # Pub/Sub for OpenRelik messaging
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── kubernetes/        # K8s resources (PVs, ConfigMaps, HPAs)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── apps/
│       ├── osdfir/        # OSDFIR Helm chart deployment
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── openrelik-importer/  # OpenRelik GCP importer
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
└── README.md              # This file
```

## Modules Overview

### 1. IAM Module (`modules/iam/`)
- **Purpose**: Manages service accounts and IAM permissions
- **Resources**: 
  - GKE node service account
  - OpenRelik GCP service account
  - IAM role bindings
  - Workload Identity bindings

### 2. Networking Module (`modules/networking/`)
- **Purpose**: Manages networking infrastructure
- **Resources**:
  - Cloud NAT router and gateway
  - Static IP for ingress
  - Firewall rules for Filestore NFS access
  - VPC network data source

### 3. Storage Module (`modules/storage/`)
- **Purpose**: Manages storage resources
- **Resources**:
  - Google Filestore instance (NFS)
  - Google Cloud Storage bucket (object storage)

### 4. GKE Module (`modules/gke/`)
- **Purpose**: Manages GKE cluster and node pools
- **Resources**:
  - GKE cluster with private nodes
  - Base node pool (always-on for core services)
  - Worker node pool (autoscaling for compute workloads)

### 5. PubSub Module (`modules/pubsub/`)
- **Purpose**: Manages Pub/Sub messaging for OpenRelik
- **Resources**:
  - Pub/Sub topic for GCS notifications
  - Pub/Sub subscription for importer
  - Storage notification configuration

### 6. Kubernetes Module (`modules/kubernetes/`)
- **Purpose**: Manages Kubernetes-specific resources
- **Resources**:
  - OSDFIR namespace
  - NFS storage class
  - Persistent Volume and PVC for Filestore
  - Timesketch ConfigMaps
  - Horizontal Pod Autoscalers

### 7. OSDFIR Applications Module (`modules/apps/osdfir/`)
- **Purpose**: Manages OSDFIR application deployment
- **Resources**:
  - OSDFIR Helm chart deployment

### 8. OpenRelik Importer Module (`modules/apps/openrelik-importer/`)
- **Purpose**: Manages OpenRelik GCP importer deployment
- **Resources**:
  - OpenRelik importer Kubernetes deployment
  - ConfigMap for importer settings
  - Service account with Workload Identity

## Migration from Monolithic to Modular

### Current State
- `main.tf` - Original monolithic configuration (legacy)
- `outputs.tf` - Original monolithic outputs (legacy)
- `openrelik-importer.tf` - Original OpenRelik importer (legacy)

### New Modular Structure
- `main-modular.tf` - New modular main configuration
- `outputs-modular.tf` - New modular outputs
- OpenRelik importer is now in `modules/apps/openrelik-importer/`

### Migration Steps

1. **Test the new modular structure** (recommended):
   ```bash
   # Initialize and plan with the new modular structure
   terraform init
   terraform plan -var-file="terraform.tfvars" -state="terraform-modular.tfstate"
   ```

2. **When ready to switch over**:
   ```bash
   # Backup the current state
   cp terraform.tfstate terraform-legacy.tfstate.backup
   
   # Rename files to use modular structure
   mv main.tf main-legacy.tf
   mv outputs.tf outputs-legacy.tf
   mv openrelik-importer.tf openrelik-importer-legacy.tf
   mv main-modular.tf main.tf
   mv outputs-modular.tf outputs.tf
   
   # Re-initialize and apply
   terraform init
   terraform plan
   terraform apply
   ```

## Benefits of Modular Architecture

1. **Separation of Concerns**: Each module has a single responsibility
2. **Reusability**: Modules can be reused across different environments
3. **Maintainability**: Easier to understand, modify, and troubleshoot
4. **Testing**: Individual modules can be tested independently
5. **Team Collaboration**: Different teams can work on different modules
6. **Version Control**: Better change tracking and code review process
7. **Application Isolation**: OpenRelik importer is properly isolated from infrastructure

## Usage

### Initialize Terraform
```bash
terraform init
```

### Plan Deployment
```bash
terraform plan -var-file="terraform.tfvars"
```

### Apply Configuration
```bash
terraform apply -var-file="terraform.tfvars"
```

### Destroy Infrastructure
```bash
terraform destroy -var-file="terraform.tfvars"
```

## Variables

All input variables remain the same as defined in `variables.tf`. The modular structure doesn't change the public interface of the Terraform configuration.

## Outputs

All outputs are preserved and aggregated from the various modules through `outputs-modular.tf`, including new outputs for the OpenRelik importer.

## Notes

- The original `openrelik-importer.tf` file has been modularized into `modules/apps/openrelik-importer/`
- All existing variable names and values are preserved for backward compatibility
- The modular structure maintains the same dependency graph as the original monolithic configuration
- OpenRelik configuration is loaded from `../openrelik/openrelik-config.toml` as before