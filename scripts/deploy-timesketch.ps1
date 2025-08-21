#!/usr/bin/env pwsh
# Wrapper script to call the Terraform deployment script from the correct directory

# Get the project root directory
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$projectRoot = Split-Path -Parent $scriptDir

# Call the actual deployment script in the terraform directory
& "$projectRoot\terraform\deploy-timesketch.ps1"