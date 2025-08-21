# Timesketch GKE Management Script
# Unified tool for deploying and managing Timesketch on Google Kubernetes Engine
# Menu-driven interface for ease of use

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("menu", "deploy", "status", "start", "stop", "restart", "logs", "cleanup", "creds", "jobs", "helm", "uninstall", "storage", "destroy", "help")]
    [string]$Action = "menu",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("development", "production")]
    [string]$Environment = "production",
    
    [Parameter(Mandatory = $false)]
    [string]$ReleaseName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "osdfir",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("timesketch")]
    [string]$Service = "timesketch",
    
    [Parameter(Mandatory = $false)]
    [string]$VarsFile = "",
    
    # Deployment options
    [switch]$DryRun = $false,
    [switch]$AutoApprove = $false,
    [switch]$Force = $false,
    [switch]$KeepInfrastructure = $false,
    [switch]$KeepNamespace = $false,
    [switch]$h = $false
)

# Color constants
$Colors = @{
    Header = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "White"
    Gray = "Gray"
    Menu = "Magenta"
}

# Global script configuration
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:TerraformDir = Join-Path $script:ProjectRoot "terraform"

function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    $ColorValue = $Colors[$Color]
    if (-not $ColorValue) {
        $ColorValue = $Colors["Info"]  # Default to white if color not found
    }
    Write-Host $Text -ForegroundColor $ColorValue
}

function Show-Header {
    param([string]$Title)
    Write-Host ""
    Write-ColorText "== $Title ==" "Header"
    Write-ColorText ("=" * ($Title.Length + 7)) "Header"
}

function Show-Banner {
    Clear-Host
    Write-ColorText "################################################################" "Header"
    Write-ColorText "||                 Timesketch GKE Manager                     ||" "Header"
    Write-ColorText "||         Unified Deployment & Management Tool               ||" "Header"
    Write-ColorText "################################################################" "Header"
    Write-ColorText "||  Timesketch for Digital Forensics & IR                     ||" "Info"
    Write-ColorText "||  Components: Timesketch                                    ||" "Info"
    Write-ColorText "||  Platform: Google Kubernetes Engine (GKE)                  ||" "Info"
    
    # Dynamic environment info
    $envLine = "||  Environment: $Environment | Namespace: $Namespace"
    $padding = " " * (61 - $envLine.Length) + "||"
    Write-ColorText ($envLine + $padding) "Success"
    
    # Get current kubectl context
    try {
        $currentContext = kubectl config current-context 2>$null
        if ($currentContext) {
            $contextLine = "||  Kubectl Context: $currentContext"
            $contextPadding = " " * (61 - $contextLine.Length) + "||"
            Write-ColorText ($contextLine + $contextPadding) "Warning"
        }
    } catch {
        Write-ColorText "||  Kubectl Context: Not configured                       ||" "Error"
    }
    
    # Release info
    $releaseLine = "||  Release: $script:ReleaseName"
    $releasePadding = " " * (61 - $releaseLine.Length) + "||"
    Write-ColorText ($releaseLine + $releasePadding) "Success"
    Write-ColorText "################################################################" "Header"
    Write-Host ""
}

function Show-QuickStatus {
    Write-ColorText "################################################################" "Header"
    Write-ColorText "||                  TIMESKETCH STATUS                        ||" "Info"
    Write-ColorText "################################################################" "Header"
    
    # Check kubectl access
    try {
        kubectl get pods -n $Namespace --no-headers 2>$null | Out-Null
        $clusterAccess = $true
    }
    catch {
        $clusterAccess = $false
    }
    
    if (-not $clusterAccess) {
        Write-ColorText "||  Status: DISCONNECTED - No cluster access                  ||" "Error"
        Write-ColorText "||  Action: Use option 1 to deploy or check credentials       ||" "Warning"
        Write-ColorText "################################################################" "Header"
        Write-Host ""
        return
    }
    
    # Quick pod summary
    $pods = kubectl get pods -n $Namespace --no-headers 2>$null
    if ($pods) {
        $runningPods = 0
        $totalPods = 0
        
        $pods | ForEach-Object {
            $totalPods++
            $parts = $_ -split '\s+'
            $status = $parts[2]
            $ready = $parts[1]
            
            if ($status -eq "Running" -and $ready -like "*/*") {
                $readyParts = $ready -split '/'
                if ($readyParts[0] -eq $readyParts[1]) {
                    $runningPods++
                }
            }
        }
        
        if ($runningPods -eq $totalPods -and $totalPods -gt 0) {
            $statusLine = "||  Status: HEALTHY - All $totalPods pods running"
            $statusPadding = " " * (64 - $statusLine.Length) + "||"
            Write-ColorText ($statusLine + $statusPadding) "Success"
        }
        elseif ($runningPods -gt 0) {
            $statusLine = "||  Status: PARTIAL - $runningPods/$totalPods pods running"
            $statusPadding = " " * (64 - $statusLine.Length) + "||"
            Write-ColorText ($statusLine + $statusPadding) "Warning"
        }
        else {
            $statusLine = "||  Status: UNHEALTHY - $totalPods pods found, none ready"
            $statusPadding = " " * (64 - $statusLine.Length) + "||"
            Write-ColorText ($statusLine + $statusPadding) "Error"
        }
    }
    else {
        Write-ColorText "||  Status: NO DEPLOYMENT - No pods in namespace              ||" "Warning"
        Write-ColorText "||  Action: Use option 1 to deploy infrastructure             ||" "Info"
    }
    
    # Check port forwarding
    $osdfirJobs = Get-Job | Where-Object { $_.Name -like "OSDFIR-*" }
    $runningJobs = $osdfirJobs | Where-Object { $_.State -eq "Running" }
    
    if ($runningJobs.Count -gt 0) {
        $accessLine = "||  Access: READY - $($runningJobs.Count) service(s) port-forwarded"
        $accessPadding = " " * (64 - $accessLine.Length) + "||"
        Write-ColorText ($accessLine + $accessPadding) "Success"
    }
    elseif ($pods -and $runningPods -gt 0) {
        Write-ColorText "||  Access: NOT READY - Use option 5 for port forwarding      ||" "Warning"
    }
    
    Write-ColorText "################################################################" "Header"
    Write-Host ""
}

function Show-MainMenu {
    Show-Banner
    Show-QuickStatus
    Write-ColorText "Select an action:" "Menu"
    Write-Host ""
    
    Write-ColorText "DEPLOYMENT:" "Success"
    Write-ColorText "  1. Deploy OSDFIR Infrastructure" "Info"
    Write-ColorText "  2. Destroy Infrastructure" "Warning"
    Write-ColorText "  3. Check Prerequisites" "Info"
    Write-Host ""
    
    Write-ColorText "MANAGEMENT:" "Success"
    Write-ColorText "  4. Show Status" "Info"
    Write-ColorText "  5. Start Services (Port Forwarding)" "Info"
    Write-ColorText "  6. Stop Services" "Info"
    Write-ColorText "  7. Restart Services" "Info"
    Write-Host ""
    
    Write-ColorText "INFORMATION:" "Success"
    Write-ColorText "  8. Get Service Credentials" "Info"
    Write-ColorText "  9. Show Service Logs" "Info"
    Write-ColorText " 10. Show Storage Usage" "Info"
    Write-ColorText " 11. Helm Status" "Info"
    Write-Host ""
    
    Write-ColorText "UTILITIES:" "Success"
    Write-ColorText " 12. Manage Background Jobs" "Info"
    Write-ColorText " 13. Cleanup Resources" "Warning"
    Write-ColorText " 14. Uninstall Helm Release" "Warning"
    Write-Host ""
    
    Write-ColorText " 15. Help" "Info"
    Write-ColorText "  0. Exit" "Gray"
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (0-15)"
    return $choice
}

function Test-Prerequisites {
    Show-Header "Checking Prerequisites"
    
    $prerequisites = @(
        @{Name = "terraform"; Command = "terraform version"; Required = $true },
        @{Name = "gcloud"; Command = "gcloud version"; Required = $true },
        @{Name = "kubectl"; Command = "kubectl version --client"; Required = $true },
        @{Name = "helm"; Command = "helm version"; Required = $true }
    )
    
    $allGood = $true
    
    foreach ($prereq in $prerequisites) {
        try {
            $null = Invoke-Expression $prereq.Command 2>$null
            Write-ColorText "[OK] $($prereq.Name) is installed" "Success"
        }
        catch {
            Write-ColorText "[ERROR] $($prereq.Name) is not installed or not in PATH" "Error"
            if ($prereq.Required) {
                $allGood = $false
            }
        }
    }
    
    # Check Google Cloud authentication
    Write-Host ""
    Write-ColorText "Checking Google Cloud authentication..." "Info"
    try {
        $gcloudAuth = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
        if ($gcloudAuth) {
            Write-ColorText "[OK] Google Cloud authenticated as: $gcloudAuth" "Success"
        }
        else {
            Write-ColorText "[ERROR] Not authenticated with Google Cloud" "Error"
            Write-ColorText "    Run: gcloud auth login" "Warning"
            $allGood = $false
        }
    }
    catch {
        Write-ColorText "[ERROR] Error checking Google Cloud authentication" "Error"
        $allGood = $false
    }
    
    Write-Host ""
    if ($allGood) {
        Write-ColorText "All prerequisites are satisfied!" "Success"
    }
    else {
        Write-ColorText "Some prerequisites are missing. Please install them before continuing." "Error"
        Write-Host ""
        Write-ColorText "Installation Guide:" "Warning"
        Write-ColorText "1. Install Chocolatey: https://chocolatey.org/install" "Info"
        Write-ColorText "2. Install tools: choco install terraform gcloud kubectl helm" "Info"
        Write-ColorText "3. Authenticate: gcloud auth login" "Info"
    }
    
    return $allGood
}

function Test-KubectlAccess {
    try {
        kubectl get pods -n $Namespace --no-headers 2>$null | Out-Null
        return $true
    }
    catch {
        Write-ColorText "ERROR: Cannot access Kubernetes cluster or namespace '$Namespace'" "Error"
        Write-ColorText "TIP: Ensure kubectl is configured and you have access to the namespace." "Warning"
        return $false
    }
}

function Start-Infrastructure {
    [CmdletBinding()]
    param()

    Show-Header "Deploy OSDFIR Infrastructure"
    Set-Location $script:TerraformDir
    
    if (-not (Test-Path $script:TerraformDir)) {
        Write-ColorText "ERROR: Terraform directory not found: ${script:TerraformDir}" "Error"
        return $false
    }
    
    # Check for terraform.tfvars file
    $tfvarsFile = if ($VarsFile) { $VarsFile } else { "terraform.tfvars" }
    
    if (-not (Test-Path $tfvarsFile)) {
        Write-ColorText "WARNING: terraform.tfvars file not found" "Warning"
        
        if (Test-Path "terraform.tfvars.example") {
            $createVars = Read-Host "Create $tfvarsFile from example? (y/n)"
            if ($createVars -eq "y" -or $createVars -eq "yes") {
                Copy-Item "terraform.tfvars.example" $tfvarsFile
                Write-ColorText "Created $tfvarsFile from example" "Success"
                Write-ColorText "Please edit $tfvarsFile with your values before continuing" "Warning"
                
                if (Get-Command "code" -ErrorAction SilentlyContinue) {
                    code $tfvarsFile
                } else {
                    notepad $tfvarsFile
                }
                
                Read-Host "Press Enter after editing the file"
            }
        }
        else {
            Write-ColorText "ERROR: terraform.tfvars.example not found" "Error"
            Set-Location $script:ProjectRoot
            return $false
        }
    }
    
    try {
        Write-ColorText "Initializing Terraform..." "Info"
        terraform init
        if ($LASTEXITCODE -ne 0) {
            Write-ColorText "ERROR: Terraform init failed" "Error"
            return $false
        }
        
        # Plan the deployment
        $planFile = "osdfir-deployment.tfplan"
        $planArgs = @("plan", "-out=$planFile")
        if ($VarsFile) { $planArgs += "-var-file=$VarsFile" }
        $planArgs += "-var=environment=$Environment"



        Write-ColorText "Planning Terraform deployment..." "Info"
        & terraform @planArgs
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorText "ERROR: Terraform plan failed" "Error"
            return $false
        }
        
        if ($DryRun) {
            Write-ColorText "Dry run completed - no changes applied" "Success"
            return $true
        }
        
        Write-ColorText "Applying saved plan (no confirmation needed)..." "Info"
        & terraform apply -auto-approve $planFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "OSDFIR Infrastructure deployed successfully!" "Success"
            # Clean up the plan file
            Remove-Item $planFile -ErrorAction SilentlyContinue
            Write-Host ""
            Write-ColorText "Getting cluster credentials..." "Info"
            
            # Get cluster credentials
            $clusterName = terraform output -raw cluster_name 2>$null
            $location = terraform output -raw cluster_location 2>$null
            $projectId = terraform output -raw project_id 2>$null
            
            if ($clusterName -and $location -and $projectId) {
                gcloud container clusters get-credentials $clusterName --zone $location --project $projectId
                Write-ColorText "Cluster credentials configured!" "Success"
            }
            
            return $true
        }
        else {
            Write-ColorText "ERROR: Terraform apply failed" "Error"
            return $false
        }
    }
    catch {
        Write-ColorText "ERROR: Exception during deployment: $($_.Exception.Message)" "Error"
        return $false
    }
    finally {
        Set-Location $script:ProjectRoot
    }
}

function Remove-Infrastructure {
    Show-Header "Destroy OSDFIR Infrastructure"
    
    Write-ColorText "WARNING: This will destroy application components but keep core infrastructure!" "Warning"
    Write-Host ""
    
    if (-not $Force) {
        $confirmation = Read-Host "Type 'yes' to confirm destruction"
        if ($confirmation -ne "yes") {
            Write-ColorText "Destruction cancelled" "Warning"
            return
        }
    }
    
    Set-Location $script:TerraformDir
    
    try {
        Write-ColorText "Destroying OSDFIR application components..." "Warning"
        $destroyTargets = @(
            "module.osdfir_apps.helm_release.osdfir",
            # OpenRelik resources removed - Timesketch-only deployment
            "module.kubernetes.kubernetes_namespace.osdfir",
            "module.kubernetes.kubernetes_config_map.timesketch_configs",
            "module.kubernetes.kubernetes_persistent_volume_claim.osdfirvolume",
            "module.kubernetes.kubernetes_persistent_volume.osdfirvolume",
            "module.kubernetes.kubernetes_storage_class.nfs_rwx"
        )
        
        $destroyArgs = @("destroy", "-auto-approve")
        foreach ($target in $destroyTargets) {
            $destroyArgs += "-target=$target"
        }
        if ($VarsFile) { $destroyArgs += "-var-file=$VarsFile" }
        $destroyArgs += "-var=environment=$Environment"
        
        & terraform @destroyArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "Application components destroyed successfully" "Success"
            Write-ColorText "Core infrastructure (storage bucket, NAT router) preserved" "Info"
        }
        else {
            Write-ColorText "ERROR: Destruction failed" "Error"
        }
    }
    finally {
        Set-Location $script:ProjectRoot
    }
}

function Show-Status {
    Show-Header "OSDFIR Deployment Status"
    
    if (-not (Test-KubectlAccess)) {
        return
    }
    
    # Check pods
    Write-ColorText "Pod Status:" "Success"
    $pods = kubectl get pods -n $Namespace --no-headers 2>$null
    if ($pods) {
        $runningPods = 0
        $totalPods = 0
        
        $pods | ForEach-Object {
            $totalPods++
            $parts = $_ -split '\s+'
            $name = $parts[0]
            $ready = $parts[1]
            $status = $parts[2]
            
            if ($status -eq "Running" -and $ready -like "*/*") {
                $readyParts = $ready -split '/'
                if ($readyParts[0] -eq $readyParts[1]) {
                    $runningPods++
                    Write-ColorText "  [OK] $name" "Success"
                } else {
                    Write-ColorText "  [WAIT] $name ($ready)" "Warning"
                }
            } else {
                Write-ColorText "  [ERROR] $name ($status)" "Error"
            }
        }
        
        Write-Host ""
        Write-ColorText "Summary: $runningPods/$totalPods pods running" "Info"
    } else {
        Write-ColorText "  No pods found in namespace '$Namespace'" "Warning"
    }
    
    # Check port forwarding jobs
    Write-Host ""
    Write-ColorText "Port Forwarding Jobs:" "Success"
    $osdfirJobs = Get-Job | Where-Object { $_.Name -like "OSDFIR-*" }
    
    if ($osdfirJobs.Count -eq 0) {
        Write-ColorText "  No port forwarding jobs running" "Warning"
        Write-ColorText "  TIP: Use option 5 to start services" "Info"
    } else {
        foreach ($job in $osdfirJobs) {
            $serviceName = $job.Name -replace "OSDFIR-", ""
            $status = switch ($job.State) {
                "Running" { "[RUNNING]" }
                "Completed" { "[STOPPED]" }
                "Failed" { "[FAILED]" }
                "Stopped" { "[STOPPED]" }
                default { "[UNKNOWN]" }
            }
            
            $color = switch ($job.State) {
                "Running" { "Success" }
                "Completed" { "Warning" }
                "Failed" { "Error" }
                "Stopped" { "Warning" }
                default { "Gray" }
            }
            
            Write-ColorText "  $status $serviceName" $color
        }
    }
}

function Start-Services {
    Show-Header "Starting OSDFIR Services"
    
    if (-not (Test-KubectlAccess)) {
        return
    }
    
    Write-ColorText "Checking service availability..." "Info"
    
    # In Start-Services function, add debugging
    Write-ColorText "Using release name: $ReleaseName" "Info"
    Write-ColorText "Looking for services in namespace: $Namespace" "Info"

    # List all services to see what's available
    kubectl get services -n $Namespace
    
    $services = @(
        @{Name="Timesketch"; Service="$ReleaseName-timesketch"; Port="5000"}
    )
    
    $availableServices = @()
    foreach ($svc in $services) {
        $null = kubectl get service $svc.Service -n $Namespace --no-headers 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "  [OK] $($svc.Name) service is available" "Success"
            $availableServices += $svc
        } else {
            Write-ColorText "  [ERROR] $($svc.Name) service not found" "Error"
        }
    }
    
    if ($availableServices.Count -eq 0) {
        Write-ColorText "ERROR: No OSDFIR services are available. Please check your deployment." "Error"
        return
    }
    
    Write-Host ""
    Write-ColorText "Starting port forwarding as background jobs..." "Info"
    
    # Stop existing OSDFIR jobs
    $existingJobs = Get-Job | Where-Object { $_.Name -like "OSDFIR-*" }
    if ($existingJobs) {
        Write-ColorText "Stopping existing jobs..." "Warning"
        $existingJobs | Stop-Job
        $existingJobs | Remove-Job -Force
    }
    
    foreach ($svc in $availableServices) {
        $jobName = "OSDFIR-$($svc.Name)"
        Write-ColorText "  Starting $($svc.Name) on port $($svc.Port)..." "Success"
        
        $scriptBlock = {
            param($service, $namespace, $port)
            kubectl port-forward -n $namespace "svc/$service" "${port}:${port}"
        }
        
        Start-Job -Name $jobName -ScriptBlock $scriptBlock -ArgumentList $svc.Service, $Namespace, $svc.Port | Out-Null
        Start-Sleep -Seconds 1
    }
    
    Write-Host ""
    Write-ColorText "Waiting for port forwarding to initialize..." "Info"
    Start-Sleep -Seconds 5
    
    Write-Host ""
    Write-ColorText "OSDFIR Services Available:" "Success"
    foreach ($svc in $availableServices) {
        Write-ColorText "  $($svc.Name): http://localhost:$($svc.Port)" "Header"
    }
    
    Write-Host ""
    Write-ColorText "Port forwarding is now active!" "Success"
}

function Stop-Services {
    Show-Header "Stopping OSDFIR Services"
    
    $osdfirJobs = Get-Job | Where-Object { $_.Name -like "OSDFIR-*" }
    if ($osdfirJobs.Count -eq 0) {
        Write-ColorText "No OSDFIR jobs found to stop" "Warning"
    } else {
        Write-ColorText "Stopping and removing OSDFIR jobs..." "Info"
        $osdfirJobs | Stop-Job
        $osdfirJobs | Remove-Job -Force
        Write-ColorText "All OSDFIR jobs stopped and removed" "Success"
    }
}

function Restart-Services {
    Show-Header "Restarting OSDFIR Services"
    
    Write-ColorText "Stopping existing services..." "Info"
    Stop-Services
    Start-Sleep -Seconds 2
    
    Write-ColorText "Starting services..." "Info"
    Start-Services
}

function Show-Logs {
    Show-Header "OSDFIR Service Logs"
    
    if (-not (Test-KubectlAccess)) {
        return
    }
    
    Write-ColorText "Recent logs from Timesketch services:" "Info"
    Write-Host ""
    
    $keyServices = @("timesketch")
    foreach ($serviceName in $keyServices) {
        $pods = kubectl get pods -n $Namespace --no-headers 2>$null | Where-Object { $_ -match $serviceName }
        if ($pods) {
            $podName = ($pods[0] -split '\s+')[0]
            Write-ColorText "Recent logs for ${podName}:" "Info"
            Write-ColorText "------------------------" "Gray"
            kubectl logs $podName -n $Namespace --tail=10 2>$null
            Write-Host ""
        }
    }
}

function Get-ServiceCredential {
    param($ServiceName, $SecretName, $SecretKey, $Username, $ServiceUrl)
    
    Write-ColorText "${ServiceName} Credentials:" "Header"
    Write-ColorText "  Service URL: $ServiceUrl" "Success"
    Write-ColorText "  Username:    $Username" "Success"
    
    try {
        $password = kubectl get secret --namespace $Namespace $SecretName -o jsonpath="{.data.$SecretKey}" 2>$null
        
        if ($password) {
            $decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
            Write-ColorText "  Password:    $decodedPassword" "Success"
        } else {
            Write-ColorText "  Password:    [Secret not found or not accessible]" "Error"
        }
    }
    catch {
        Write-ColorText "  Password:    [Error retrieving secret]" "Error"
    }
    
    Write-Host ""
}

function Show-Credentials {
    Show-Header "OSDFIR Service Credentials"
    
    if (-not (Test-KubectlAccess)) {
        return
    }
    
    Write-ColorText "Retrieving credentials for release '$ReleaseName' in namespace '$Namespace'..." "Info"
    Write-Host ""
    
    # Get Timesketch credentials
    $timesketchSecret = kubectl get secret --namespace $Namespace "$ReleaseName-timesketch-secret" 2>$null
    if ($timesketchSecret) {
        Get-ServiceCredential -ServiceName "Timesketch" -SecretName "$ReleaseName-timesketch-secret" -SecretKey "timesketch-user" -Username "admin" -ServiceUrl "http://localhost:5000"
    } else {
        Write-ColorText "ERROR: No Timesketch credential secrets found for release '$ReleaseName' in namespace '$Namespace'" "Error"
    }
    
    Write-ColorText "NOTE: Change default credentials in production environments!" "Warning"
}

function Show-Storage {
    Show-Header "PV Storage Utilization"
    
    if (-not (Test-KubectlAccess)) { 
        return 
    }
    
    # Fetch all pods in namespace
    $podsJson = kubectl get pods -n $Namespace -o json | ConvertFrom-Json
    foreach ($pod in $podsJson.items) {
        $podName = $pod.metadata.name
        # Inspect each volume for PVC mounts
        foreach ($vol in $pod.spec.volumes) {
            if ($vol.persistentVolumeClaim) {
                $pvcName = $vol.persistentVolumeClaim.claimName
                # Find corresponding mountPath
                $mountObj = $pod.spec.containers[0].volumeMounts | Where-Object { $_.name -eq $vol.name }
                if ($mountObj) {
                    $mountPath = $mountObj.mountPath
                    Write-ColorText "Pod: $podName" "Info"
                    Write-ColorText "  PVC:       $pvcName" "Success"
                    Write-ColorText "  MountPath: $mountPath" "Success"
                    # Run df to get storage info
                    $df = kubectl exec -n $Namespace $podName -- df -h $mountPath 2>$null
                    $lines = $df -split "`n"
                    if ($lines.Length -gt 1) {
                        $info = $lines[1].Trim()
                        $parts = $info -split '\s+'
                        Write-ColorText "  Filesystem: $($parts[0])" "Success"
                        Write-ColorText "  Size:       $($parts[1])" "Success"
                        Write-ColorText "  Used:       $($parts[2])" "Success"
                        Write-ColorText "  Avail:      $($parts[3])" "Success"
                        Write-ColorText "  Use%:       $($parts[4])" "Success"
                    } else {
                        Write-ColorText "  Unable to retrieve storage info." "Error"
                    }
                    Write-Host ""
                }
            }
        }
    }
}

function Show-Helm {
    Show-Header "Helm Releases and Status"
    
    helm list -n $Namespace
    Write-Host ""
    Write-ColorText "Release Status:" "Success"
    helm status $ReleaseName -n $Namespace
}

function Uninstall-Release {
    Show-Header "Uninstalling OSDFIR Helm Release"
    
    Write-ColorText "WARNING: This will remove the Helm release but keep infrastructure!" "Warning"
    
    if (-not $Force) {
        $confirmation = Read-Host "Uninstall Helm release '$ReleaseName'? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-ColorText "Uninstall cancelled" "Warning"
            return
        }
    }
    
    helm uninstall $ReleaseName -n $Namespace
}

function Show-Jobs {
    Show-Header "OSDFIR Background Jobs"
    
    $osdfirJobs = Get-Job | Where-Object { $_.Name -like "OSDFIR-*" }
    if ($osdfirJobs.Count -eq 0) {
        Write-ColorText "No OSDFIR jobs found" "Warning"
    } else {
        foreach ($job in $osdfirJobs) {
            $serviceName = $job.Name -replace "OSDFIR-", ""
            $status = switch ($job.State) {
                "Running" { "[RUNNING]" }
                "Completed" { "[STOPPED]" }
                "Failed" { "[FAILED]" }
                "Stopped" { "[STOPPED]" }
                default { "[UNKNOWN]" }
            }
            $color = switch ($job.State) {
                "Running" { "Success" }
                "Failed" { "Error" }
                "Stopped" { "Warning" }
                default { "Gray" }
            }
            Write-ColorText "  $status $serviceName" $color
        }
    }
}

function Clear-Resources {
    Show-Header "OSDFIR Cleanup"
    
    Write-ColorText "Timesketch Cleanup - Use with caution!" "Error"
    if (-not $Force) {
        $confirmation = Read-Host "Are you sure you want to cleanup OSDFIR resources? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-ColorText "Cleanup cancelled" "Warning"
            return
        }
    }
    
    Write-ColorText "Cleaning up OSDFIR jobs..." "Warning"
    $osdfirJobs = Get-Job | Where-Object { $_.Name -like "OSDFIR-*" }
    if ($osdfirJobs) {
        $osdfirJobs | Stop-Job
        $osdfirJobs | Remove-Job -Force
        Write-ColorText "OSDFIR jobs cleaned up" "Success"
    } else {
        Write-ColorText "No OSDFIR jobs found to clean up" "Info"
    }
}

function Show-Help {
    Show-Header "Timesketch GKE Manager Help"
    Write-Host ""
    Write-ColorText "Usage: .\manage-osdfir-gke.ps1 [action] [options]" "Warning"
    Write-Host ""
    Write-ColorText "Actions:" "Success"
    Write-ColorText "  menu      - Show interactive menu (default)"
    Write-ColorText "  deploy    - Deploy OSDFIR infrastructure"
    Write-ColorText "  destroy   - Destroy infrastructure"
    Write-ColorText "  status    - Show deployment and service status"
    Write-ColorText "  start     - Start port forwarding for services"
    Write-ColorText "  stop      - Stop port forwarding jobs"
    Write-ColorText "  restart   - Restart port forwarding jobs"
    Write-ColorText "  logs      - Show logs from services"
    Write-ColorText "  creds     - Get service credentials"
    Write-ColorText "  storage   - Show PV storage utilization"
    Write-ColorText "  helm      - Show Helm status"
    Write-ColorText "  uninstall - Uninstall Helm release"
    Write-ColorText "  jobs      - Manage background jobs"
    Write-ColorText "  cleanup   - Clean up resources"
    Write-ColorText "  help      - Show this help message"
    Write-Host ""
    Write-ColorText "Options:" "Success"
    Write-ColorText "  -Environment      Environment config (development, production)"
    Write-ColorText "  -ReleaseName      Helm release name (auto-detected)"
    Write-ColorText "  -Namespace        Kubernetes namespace (default: osdfir)"
    Write-ColorText "  -Service          Specific service for creds (timesketch)"
    Write-ColorText "  -DryRun           Show what would be deployed without applying"
    Write-ColorText "  -AutoApprove      Skip interactive approval"
    Write-ColorText "  -Force            Skip confirmations"
    Write-Host ""
    Write-ColorText "Examples:" "Header"
    Write-ColorText "  .\manage-osdfir-gke.ps1"
    Write-ColorText "  .\manage-osdfir-gke.ps1 deploy -Environment development"
    Write-ColorText "  .\manage-osdfir-gke.ps1 start"
    Write-ColorText "  .\manage-osdfir-gke.ps1 creds -Service timesketch"
}

# Initialize
function Initialize-Script {
    # Auto-detect Helm release name if not provided
    if (-not $ReleaseName) {
        try {
            $releases = helm list -n $Namespace -o json | ConvertFrom-Json
            if ($releases.Count -eq 1) {
                $script:ReleaseName = $releases[0].name
                Write-ColorText "Auto-detected release name: $($script:ReleaseName)" "Info"
            } elseif ($releases.Count -gt 1) {
                $script:ReleaseName = $releases[0].name
                Write-ColorText "Multiple releases found; using '${script:ReleaseName}'" "Warning"
            } else {
                $script:ReleaseName = "osdfir-fci"  # Changed from osdfir-infra
                Write-ColorText "No releases found; using default '${script:ReleaseName}'" "Info"
            }
        } catch {
            $script:ReleaseName = "osdfir-fci"  # Changed from osdfir-infra
        }
    } else {
        $script:ReleaseName = $ReleaseName
    }
}

# Handle -h flag for help
if ($h) {
    $Action = "help"
}

# Initialize script
Initialize-Script

# Main script logic
if ($Action -eq "menu") {
    do {
        $choice = Show-MainMenu
        
        switch ($choice) {
            "1" { 
                Start-Infrastructure
                Read-Host "Press Enter to continue"
            }
            "2" { 
                Remove-Infrastructure
                Read-Host "Press Enter to continue"
            }
            "3" { 
                Test-Prerequisites
                Read-Host "Press Enter to continue"
            }
            "4" { 
                Show-Status
                Read-Host "Press Enter to continue"
            }
            "5" { 
                Start-Services
                Read-Host "Press Enter to continue"
            }
            "6" { 
                Stop-Services
                Read-Host "Press Enter to continue"
            }
            "7" { 
                Restart-Services
                Read-Host "Press Enter to continue"
            }
            "8" { 
                Show-Credentials
                Read-Host "Press Enter to continue"
            }
            "9" { 
                Show-Logs
                Read-Host "Press Enter to continue"
            }
            "10" { 
                Show-Storage
                Read-Host "Press Enter to continue"
            }
            "11" { 
                Show-Helm
                Read-Host "Press Enter to continue"
            }
            "12" { 
                Show-Jobs
                Read-Host "Press Enter to continue"
            }
            "13" { 
                Clear-Resources
                Read-Host "Press Enter to continue"
            }
            "14" { 
                Uninstall-Release
                Read-Host "Press Enter to continue"
            }
            "15" { 
                Show-Help
                Read-Host "Press Enter to continue"
            }
            "0" { 
                Write-ColorText "Goodbye!" "Success"
                break
            }
            default { 
                Write-ColorText "Invalid choice. Please try again." "Error"
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice -ne "0")
} else {
    # Direct command execution
    switch ($Action.ToLower()) {
        "deploy" { Start-Infrastructure }
        "destroy" { Remove-Infrastructure }
        "status" { Show-Status }
        "start" { Start-Services }
        "stop" { Stop-Services }
        "restart" { Restart-Services }
        "logs" { Show-Logs }
        "creds" { Show-Credentials }
        "storage" { Show-Storage }
        "helm" { Show-Helm }
        "uninstall" { Uninstall-Release }
        "jobs" { Show-Jobs }
        "cleanup" { Clear-Resources }
        "help" { Show-Help }
        default { Show-Help }
    }
} 