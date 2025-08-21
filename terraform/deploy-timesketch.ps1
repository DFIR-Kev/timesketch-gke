#!/usr/bin/env pwsh
# Timesketch GKE Deployment Script
# This script handles the two-phase deployment of Timesketch on GKE:
# 1. First deploys core GCP infrastructure (GKE, Filestore, Storage)
# 2. Then deploys Kubernetes resources and Timesketch Helm chart

# Ensure we're in the terraform directory
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
Set-Location $scriptDir

# Error handling
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Write-Host "Starting Timesketch GKE deployment process..." -ForegroundColor Cyan
Write-Host ""

# Step 1: Initialize Terraform
Write-Host "Initializing Terraform..." -ForegroundColor Yellow
terraform init

# Step 2: Deploy infrastructure (GKE, Filestore, etc.)
Write-Host ""
Write-Host "Phase 1: Deploying core infrastructure (GKE, Filestore)..." -ForegroundColor Cyan
Write-Host "This will create the GKE cluster and supporting infrastructure" -ForegroundColor Yellow

# Check for existing buckets and handle appropriately
Write-Host "Checking for existing buckets..." -ForegroundColor Yellow
$tfvarsContent = Get-Content -Path "terraform.tfvars" -ErrorAction SilentlyContinue
$bucketName = ""

# Try to extract bucket name from terraform.tfvars
foreach ($line in $tfvarsContent) {
    if ($line -match 'bucket_name\s*=\s*"([^"]+)"') {
        $bucketName = $Matches[1]
        break
    }
}

# If not found in terraform.tfvars, check variables.tf for default
if (-not $bucketName) {
    $variablesContent = Get-Content -Path "variables.tf" -ErrorAction SilentlyContinue
    $inBucketBlock = $false
    foreach ($line in $variablesContent) {
        if ($line -match 'variable\s+"bucket_name"') {
            $inBucketBlock = $true
            continue
        }
        if ($inBucketBlock -and $line -match 'default\s*=\s*"([^"]+)"') {
            $bucketName = $Matches[1]
            break
        }
        if ($inBucketBlock -and $line -match '}') {
            $inBucketBlock = $false
        }
    }
}

# Default fallback if still not found
if (-not $bucketName) {
    $bucketName = "timesketch-data-bucket"
}

# Check if the old "openrelik-data-bucket" exists
$oldBucketName = "openrelik-data-bucket"
gsutil ls -b "gs://$oldBucketName" >$null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Found existing bucket: $oldBucketName" -ForegroundColor Yellow
    Write-Host "We'll use this bucket but rename it in Terraform to: $bucketName" -ForegroundColor Yellow
    
    # Update terraform.tfvars if it exists
    if (Test-Path "terraform.tfvars") {
        $tfvarsContent = Get-Content -Path "terraform.tfvars"
        $updatedContent = @()
        $bucketUpdated = $false
        
        foreach ($line in $tfvarsContent) {
            if ($line -match 'bucket_name\s*=') {
                $updatedContent += "bucket_name = `"$oldBucketName`""
                $bucketUpdated = $true
            } else {
                $updatedContent += $line
            }
        }
        
        if (-not $bucketUpdated) {
            $updatedContent += "bucket_name = `"$oldBucketName`""
        }
        
        Set-Content -Path "terraform.tfvars" -Value $updatedContent
        Write-Host "Updated terraform.tfvars to use existing bucket name" -ForegroundColor Green
    } else {
        # Create a new terraform.tfvars file
        Set-Content -Path "terraform.tfvars" -Value "bucket_name = `"$oldBucketName`""
        Write-Host "Created terraform.tfvars with existing bucket name" -ForegroundColor Green
    }
    
    # Now the bucket name in our config matches the existing bucket
    $bucketName = $oldBucketName
}

# Check if the specified bucket exists and import if needed
gsutil ls -b "gs://$bucketName" >$null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Bucket $bucketName exists, will import it to Terraform state" -ForegroundColor Yellow
    terraform import module.storage.google_storage_bucket.timesketch_data $bucketName
}

# Create the infrastructure plan
terraform plan "-target=module.iam" "-target=module.networking" "-target=module.storage" "-target=module.gke" "-out=timesketch-infra.tfplan"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform plan for infrastructure failed" -ForegroundColor Red
    exit 1
}

# Apply the infrastructure plan
terraform apply "timesketch-infra.tfplan"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform apply for infrastructure failed" -ForegroundColor Red
    exit 1
}

# Step 3: Configure kubectl to connect to the new cluster
Write-Host ""
Write-Host "Configuring kubectl to connect to the GKE cluster..." -ForegroundColor Yellow
$projectId = terraform output -raw project_id
$zone = terraform output -raw zone
$clusterName = terraform output -raw cluster_name

gcloud container clusters get-credentials $clusterName --zone $zone --project $projectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to configure kubectl" -ForegroundColor Red
    exit 1
}

# Step 4: Wait for the cluster to be ready
Write-Host "Waiting for the GKE cluster to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Step 5: Check for existing legacy HPAs and remove them if needed
Write-Host ""
Write-Host "Checking for legacy HPAs that might cause conflicts (from previous deployments)..." -ForegroundColor Yellow

# These HPAs are from previous OpenRelik deployments and need to be removed
# to avoid conflicts with our Timesketch-only deployment
$legacyHpas = @(
    "openrelik-worker-plaso-hpa",
    "openrelik-worker-strings-hpa",
    "openrelik-worker-extraction-hpa",
    "openrelik-gcp-importer-hpa"
)

# Get namespace from Terraform
$namespace = "osdfir"
try {
    $namespace = terraform output -raw namespace_name 2>$null
} catch {
    # Use default namespace if not found
}

foreach ($hpa in $legacyHpas) {
    # Check if HPA exists and delete if found
    kubectl get hpa $hpa -n $namespace >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Removing legacy HPA: $hpa" -ForegroundColor Yellow
        kubectl delete hpa $hpa -n $namespace
    }
}

# Step 6: Deploy Kubernetes resources and Timesketch
Write-Host ""
Write-Host "Phase 2: Deploying Kubernetes resources and Timesketch..." -ForegroundColor Cyan
Write-Host "This will create the Kubernetes resources and deploy Timesketch" -ForegroundColor Yellow

# Check if storage class exists
Write-Host "Checking for required storage classes..." -ForegroundColor Yellow
kubectl get storageclass premium-rwo >$null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Required storage class 'premium-rwo' not found in the cluster" -ForegroundColor Red
    Write-Host "Available storage classes:" -ForegroundColor Yellow
    kubectl get storageclass
    
    Write-Host "Please update helm/osdfir-production-values.yaml to use one of the available storage classes" -ForegroundColor Yellow
    exit 1
}

# Create the applications plan
terraform plan "-target=module.kubernetes" "-target=module.osdfir_apps" "-out=timesketch-apps.tfplan"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform plan for applications failed" -ForegroundColor Red
    exit 1
}

# Apply the applications plan
terraform apply "timesketch-apps.tfplan"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform apply for applications failed" -ForegroundColor Red
    exit 1
}

# Verify the Helm release was created
Write-Host "Verifying Helm release..." -ForegroundColor Yellow
helm list -n $namespace >$null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Helm release not found. Checking for errors..." -ForegroundColor Yellow
    
    # Check for common issues
    Write-Host "Checking for common deployment issues:" -ForegroundColor Yellow
    
    # Check for storage class issues
    kubectl get events -n $namespace | Select-String -Pattern "storage|volume|pvc|pv" -CaseSensitive:$false
    
    # Check for resource constraints
    kubectl get events -n $namespace | Select-String -Pattern "insufficient|resources|memory|cpu" -CaseSensitive:$false
    
    # General errors
    kubectl get events -n $namespace | Select-String -Pattern "error|fail|warn" -CaseSensitive:$false
    
    Write-Host "You may need to manually troubleshoot the deployment using kubectl and helm commands" -ForegroundColor Yellow
}

# Step 7: Verify Timesketch pods are running
Write-Host ""
Write-Host "Verifying Timesketch pods..." -ForegroundColor Yellow
$maxRetries = 5
$retryCount = 0
$podsRunning = $false

while ($retryCount -lt $maxRetries -and -not $podsRunning) {
    Write-Host "Checking for Timesketch pods (attempt $($retryCount + 1)/$maxRetries)..." -ForegroundColor Yellow
    
    # Check for Timesketch pods
    kubectl get pods -n $namespace -l app.kubernetes.io/name=timesketch >$null 2>&1
    if ($LASTEXITCODE -eq 0) {
        $timesketchPods = kubectl get pods -n $namespace -l app.kubernetes.io/name=timesketch -o jsonpath="{.items[*].status.phase}"
        if ($timesketchPods -match "Running") {
            $podsRunning = $true
            Write-Host "Timesketch pods are running!" -ForegroundColor Green
            break
        }
    }
    
    Write-Host "Timesketch pods not ready yet. Waiting 30 seconds before retrying..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    $retryCount++
}

if (-not $podsRunning) {
    Write-Host "WARNING: Timesketch pods are not running. You may need to troubleshoot the deployment." -ForegroundColor Yellow
    kubectl get pods -n $namespace
}

# Step 8: Display deployment complete message
Write-Host ""
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "You can now use the manage-osdfir-gke.ps1 script to manage your Timesketch deployment" -ForegroundColor Green
Write-Host ""
Write-Host "To access Timesketch, run: .\scripts\manage-osdfir-gke.ps1 -Action PortForward" -ForegroundColor Yellow
Write-Host "Then access Timesketch at: http://localhost:5000" -ForegroundColor Yellow
Write-Host ""
Write-Host "To get credentials, run: .\scripts\manage-osdfir-gke.ps1 -Action Credentials" -ForegroundColor Yellow