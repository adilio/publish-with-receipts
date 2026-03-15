# Initialize-Module.ps1
#
# Loaded via ScriptsToProcess in ExampleModule.psd1.
# This runs in the CALLER'S session scope before the module is imported.
#
# NOTE: This file is intentionally present to demonstrate the ScriptsToProcess
# attack surface documented in Aqua Security's typosquatting research (2023).
# In this demo, it does nothing harmful — but the mechanism allows a malicious
# publisher to execute arbitrary code at import time.

Write-Verbose "[ExampleModule] Initialization script loaded." -Verbose:$false
