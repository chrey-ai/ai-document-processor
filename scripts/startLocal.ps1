<#
.SYNOPSIS
Starts the Azure Functions app locally with optional remote settings fetch.

.PARAMETER SkipSettings
Skip fetching remote settings from Azure (use existing local.settings.json).

.PARAMETER SkipVenv
Skip virtual environment setup (assume it already exists and has dependencies).

.EXAMPLE
.\startLocal.ps1
# Full startup: fetch settings, setup venv, start function

.EXAMPLE
.\startLocal.ps1 -SkipSettings -SkipVenv
# Quick restart: use existing settings and venv
#>

param(
    [switch]$SkipSettings,
    [switch]$SkipVenv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve script and repo directories
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$pipelineDir = Join-Path $repoRoot "pipeline"

Set-Location $pipelineDir

# Fetch remote settings unless -SkipSettings is passed
if (-not $SkipSettings) {
    Write-Host "Fetching remote settings..." -ForegroundColor Cyan

    # Load azd environment values
    azd env get-values | ForEach-Object {
        if ($_ -match '^(?<key>[^=]+)=(?<val>.*)$') {
            $k = $matches.key.Trim()
            $v = $matches.val

            # Remove outer quotes if present
            if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) {
                $v = $v.Substring(1, $v.Length - 2)
                $v = $v -replace '\\"', '"'
            }

            [Environment]::SetEnvironmentVariable($k, $v)
            Set-Variable -Name $k -Value $v -Scope Script -Force
        }
    }

    # Validate required environment variables
    if (-not $env:PROCESSING_FUNCTION_APP_NAME) { throw "PROCESSING_FUNCTION_APP_NAME not set." }
    if (-not $env:APP_CONFIG_NAME) { throw "APP_CONFIG_NAME not set." }
    # Fetch app settings from Azure
    func azure functionapp fetch-app-settings $env:PROCESSING_FUNCTION_APP_NAME --decrypt
    func settings decrypt

    # Use the signed-in developer identity for local Azure service access.
    $localSettingsPath = "local.settings.json"
    if (-not (Test-Path $localSettingsPath)) { throw "File not found: $localSettingsPath" }

    $json = Get-Content $localSettingsPath -Raw | ConvertFrom-Json -AsHashtable

    if (-not $json.ContainsKey('Values') -or -not $json['Values']) {
        $json['Values'] = @{}
    }

    @(
        'AZURE_CLIENT_ID',
        'AZURE_APPCONFIG_CONNECTION_STRING',
        'AzureWebJobsStorage',
        'AzureWebJobsStorage__credential',
        'AzureWebJobsStorage__clientId',
        'DataStorage',
        'DataStorage__credential',
        'DataStorage__clientId'
    ) | ForEach-Object {
        $json['Values'].Remove($_)
    }

    $json | ConvertTo-Json -Depth 10 | Set-Content $localSettingsPath -Encoding UTF8

    Write-Host "Updated local.settings.json" -ForegroundColor Green
}
else {
    Write-Host "Skipping settings fetch (-SkipSettings)" -ForegroundColor Yellow
}

Remove-Item -Path Env:AZURE_CLIENT_ID -ErrorAction SilentlyContinue
[Environment]::SetEnvironmentVariable('AZURE_TOKEN_CREDENTIALS', 'AzureCliCredential')
Remove-Variable -Name AZURE_CLIENT_ID -Scope Script -ErrorAction SilentlyContinue
@('OPENAI_API_BASE', 'OPENAI_API_VERSION', 'OPENAI_MODEL') | ForEach-Object {
    Remove-Item -Path "Env:$_" -ErrorAction SilentlyContinue
    Remove-Variable -Name $_ -Scope Script -ErrorAction SilentlyContinue
}

# Set up virtual environment unless -SkipVenv is passed
if (-not $SkipVenv) {
    Write-Host "Setting up Python virtual environment..." -ForegroundColor Cyan

    if (-not (Test-Path .venv)) {
        Write-Host "Creating virtual environment..."
        python -m venv .venv
    }

    # Activate venv
    $activate = Join-Path .venv "Scripts\Activate.ps1"
    if (-not (Test-Path $activate)) {
        throw "Activation script not found at $activate"
    }
    & $activate

    # Install dependencies
    pip install -r requirements.txt
}
else {
    Write-Host "Skipping venv setup (-SkipVenv)" -ForegroundColor Yellow

    # Still need to activate existing venv
    $activate = Join-Path .venv "Scripts\Activate.ps1"
    if (Test-Path $activate) {
        & $activate
    }
}

Write-Host "Starting Azure Functions..." -ForegroundColor Cyan
func start --build
