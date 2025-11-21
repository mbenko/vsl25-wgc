# Publish Single Bicep Module to ACR
# Usage: .\scripts\publish-module.ps1 -ModuleName $m -AcrName $acr
# Usage: .\publish-single-module.ps1 -ModuleName "containerapp" -Version "v1.3" -Force
# Usage: .\publish-single-module.ps1 -ModuleName "sqlserver" (uses auto-detected next version)

param(
    [Parameter(Mandatory=$true)]
    [string]$ModuleName,
    [string]$Version,
    [switch]$Force,
    [switch]$AutoVersion,
    [string]$AcrName = "bnk25acr"
)

$acr = $AcrName

# Function to get the latest version for a module
function Get-LatestModuleVersion {
    param([string]$ModuleName)
    
    # Convert module name to lowercase for ACR
    $acrModuleName = $ModuleName.ToLower()
    
    try {
        $tags = az acr repository show-tags --name $acr --repository "bicep/modules/$acrModuleName" --orderby time_desc --output json | ConvertFrom-Json
        
        if ($tags -and $tags.Count -gt 0) {
            # Filter out 'latest' tag and get versioned tags
            $versionTags = $tags | Where-Object { $_ -ne "latest" -and $_ -match "^v\d+\.\d+$" }
            
            if ($versionTags.Count -gt 0) {
                $latestTag = $versionTags[0]
                Write-Host "Latest published version for ${ModuleName}: $latestTag" -ForegroundColor Yellow
                return $latestTag
            }
        }
        
        Write-Host "No previous versions found for $ModuleName" -ForegroundColor Yellow
        return $null  # Return null instead of v0.1 to distinguish "no versions" from "v0.1 exists"
    }
    catch {
        Write-Host "Could not retrieve version info for $ModuleName, starting fresh" -ForegroundColor Yellow
        return $null
    }
}

# Function to increment version
function Get-NextVersion {
    param([string]$CurrentVersion)
    
    if ($CurrentVersion -match "^v(\d+)\.(\d+)$") {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $newMinor = $minor + 1
        return "v$major.$newMinor"
    }
    return "v0.2"
}

# Function to publish a module with version tag and create latest alias
function Publish-Module {
    param(
        [string]$FilePath,
        [string]$ModuleName,
        [string]$Version,
        [string]$ForceFlag
    )
    
    Write-Host "Publishing $ModuleName..." -ForegroundColor Cyan
    
    # Convert module name to lowercase for ACR (ACR requires lowercase)
    $acrModuleName = $ModuleName.ToLower()
    
    # Publish with specific version tag
    Write-Host "  Publishing version $Version..." -ForegroundColor Gray
    az bicep publish --file $FilePath --target "br:$acr.azurecr.io/bicep/modules/${acrModuleName}:$Version" $ForceFlag
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to publish $ModuleName version $Version"
        return $false
    }
    
    # Create latest tag as an alias to the version tag (same digest)
    Write-Host "  Creating latest tag alias..." -ForegroundColor Gray
    # Always use --force for latest tag to update it to point to the new version
    az acr import --name $acr --source "$acr.azurecr.io/bicep/modules/${acrModuleName}:$Version" --image "bicep/modules/${acrModuleName}:latest" --force
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create latest tag alias for $ModuleName"
        return $false
    }
    
    Write-Host "  ✅ Successfully published ${ModuleName}:$Version" -ForegroundColor Green
    return $true
}

# Validate module exists
$modulePath = "infra/modules/$ModuleName.bicep"
if (-not (Test-Path $modulePath)) {
    Write-Error "Module file not found: $modulePath"
    Write-Host "Available modules:" -ForegroundColor Yellow
    Get-ChildItem "infra/modules" -Filter "*.bicep" | ForEach-Object { 
        Write-Host "  - $($_.BaseName)" -ForegroundColor Cyan 
    }
    exit 1
}

# Determine version to use
if (-not $Version -or $AutoVersion) {
    $latestVersion = Get-LatestModuleVersion -ModuleName $ModuleName
    if ($AutoVersion -or -not $Version) {
        if ($null -eq $latestVersion) {
            # No previous versions exist, start at v0.1
            $Version = "v0.1"
            Write-Host "Starting fresh with version $Version" -ForegroundColor Green
        } else {
            # Auto-increment from existing version
            $Version = Get-NextVersion -CurrentVersion $latestVersion
            Write-Host "Auto-incrementing version from $latestVersion to $Version" -ForegroundColor Green
        }
    } else {
        $Version = $latestVersion ?? "v0.1"
        Write-Host "No version specified, using: $Version" -ForegroundColor Yellow
    }
}

# Validate version format
if ($Version -notmatch "^v\d+\.\d+$") {
    Write-Error "Version must be in format 'v1.0', 'v2.1', etc. Got: $Version"
    exit 1
}

Write-Host "Publishing module '$ModuleName' version '$Version' to ACR '$acr'" -ForegroundColor Green
if ($Force) {
    Write-Host "Using --force to overwrite existing modules" -ForegroundColor Yellow
}

$forceFlag = if ($Force) { "--force" } else { "" }

# Publish the module
$success = Publish-Module -FilePath $modulePath -ModuleName $ModuleName -Version $Version -ForceFlag $forceFlag

if ($success) {
    Write-Host "✅ Module publishing complete!" -ForegroundColor Green
    Write-Host "Published: br:$acr.azurecr.io/bicep/modules/${ModuleName}:$Version" -ForegroundColor Cyan
    Write-Host "Latest:    br:$acr.azurecr.io/bicep/modules/${ModuleName}:latest" -ForegroundColor Cyan
} else {
    Write-Host "❌ Module publishing failed!" -ForegroundColor Red
    exit 1
}
