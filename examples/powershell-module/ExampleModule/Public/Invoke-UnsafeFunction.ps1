function Invoke-UnsafeFunction {
    <#
    .SYNOPSIS
        Fetches and applies configuration from a remote endpoint.

    .DESCRIPTION
        THIS FUNCTION CONTAINS INTENTIONAL SECURITY ANTI-PATTERNS for
        supply chain security demonstration purposes. Each flaw is labelled
        with the Semgrep rule that should detect it.

        This file is intentionally kept under active edit so the demo PR
        exercises the security scanning workflow end-to-end.

        DO NOT use these patterns in production code.

    .PARAMETER ConfigUrl
        URL to fetch configuration from. No input validation is performed.
    #>
    [CmdletBinding()]
    param(
        # INTENTIONAL FLAW: No [ValidateNotNullOrEmpty()] or [ValidatePattern()] on a URL parameter.
        # An attacker who controls input can supply a malicious URL.
        [Parameter(Mandatory)]
        [string] $ConfigUrl
    )

    # INTENTIONAL FLAW: Hardcoded API key.
    # Semgrep rule: powershell-hardcoded-secret
    # This key will be captured in SARIF output and surfaced as a PR annotation.
    $ApiKey = "sk-live-abcdef1234567890abcdef1234567890"

    # INTENTIONAL FLAW: Disabling TLS certificate validation.
    # Semgrep rule: powershell-disable-certificate-validation
    # This allows MITM attacks against any subsequent HTTPS request in this session.
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

    # INTENTIONAL FLAW: Download-and-execute pattern.
    # Semgrep rule: powershell-download-execute
    # The result of Invoke-WebRequest is directly executed via Invoke-Expression.
    # An attacker who controls $ConfigUrl (or the server it points to) can execute
    # arbitrary code in the context of the calling user.
    $remoteScript = Invoke-WebRequest -Uri $ConfigUrl -Headers @{ 'X-Api-Key' = $ApiKey }
    Invoke-Expression $remoteScript.Content

    # INTENTIONAL FLAW: Base64 encoded command execution.
    # Semgrep rule: powershell-encoded-command
    # Encoding commands in Base64 is a common obfuscation technique.
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Write-Host 'post-config hook'"))
    powershell.exe -EncodedCommand $encoded
}
