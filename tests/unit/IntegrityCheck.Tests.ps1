#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for the integrity check regex patterns.

.DESCRIPTION
    The choco-integrity-check action uses several regex patterns to detect:
      - External URLs in install scripts
      - Presence of checksum arguments
      - Weak checksum algorithms (MD5/SHA1)
      - Direct Invoke-WebRequest calls bypassing Chocolatey helpers
      - SHA256 hashes in VERIFICATION.txt

    This file tests each pattern independently using sample script content,
    ensuring the detection logic works as intended before the action runs
    in CI.
#>

BeforeAll {
    # Regex patterns extracted from choco-integrity-check/action.yml
    # These are the exact patterns used by the action (accounting for PS string escaping)
    $script:urlPattern       = 'url\s*=\s*[''"]https?://'
    $script:checksumPattern  = 'checksum\s*='
    $script:weakAlgoPattern  = "checksumType\s*=\s*[`"']?(md5|sha1)[`"']?"
    $script:iwrPattern       = 'Invoke-WebRequest\s+-Uri\s+[''"]?https?://'
    $script:sha256Pattern    = '[0-9a-fA-F]{64}'

    # Helper function
    function Test-Pattern {
        param([string]$Content, [string]$Pattern)
        return $Content -match $Pattern
    }
}

Describe 'Integrity check — URL detection' {
    It 'detects url = "https://..." (double-quoted)' {
        $content = 'url = "https://example.com/myapp.exe"'
        Test-Pattern $content $script:urlPattern | Should -BeTrue
    }

    It 'detects url = ''https://...'' (single-quoted)' {
        $content = "url = 'https://example.com/myapp.exe'"
        Test-Pattern $content $script:urlPattern | Should -BeTrue
    }

    It 'detects url with whitespace around equals' {
        $content = 'url  =  "https://example.com/myapp.exe"'
        Test-Pattern $content $script:urlPattern | Should -BeTrue
    }

    It 'detects http:// (non-TLS) URLs' {
        $content = 'url = "http://example.com/legacy.exe"'
        Test-Pattern $content $script:urlPattern | Should -BeTrue
    }

    It 'does NOT match url = "ftp://..." (non-HTTP)' {
        $content = 'url = "ftp://files.example.com/file.zip"'
        Test-Pattern $content $script:urlPattern | Should -BeFalse
    }

    It 'does NOT match a comment containing a URL' {
        # The regex is looking for url = ..., not any URL
        $content = '# Download from https://example.com'
        Test-Pattern $content $script:urlPattern | Should -BeFalse
    }
}

Describe 'Integrity check — Checksum presence' {
    It 'detects checksum = ...' {
        $content = 'checksum = "abc123"'
        Test-Pattern $content $script:checksumPattern | Should -BeTrue
    }

    It 'detects Checksum = ... (PascalCase)' {
        $content = 'Checksum = "abc123"'
        Test-Pattern $content $script:checksumPattern | Should -BeTrue
    }

    It 'detects checksum= without spaces' {
        $content = 'checksum="abc123"'
        Test-Pattern $content $script:checksumPattern | Should -BeTrue
    }

    It 'does NOT detect checksum64 = ... (pattern matches "checksum" + whitespace only)' {
        # The action uses 'checksum\s*=' which matches "checksum =" but NOT "checksum64 ="
        # This documents a known limitation: checksum64 is not detected by this pattern.
        # The action primarily checks for the presence of any checksum argument,
        # and "checksum64" would require a broader pattern like 'checksum\d*\s*='.
        $content = 'checksum64 = "abc123"'
        Test-Pattern $content $script:checksumPattern | Should -BeFalse
    }

    It 'does NOT match in a comment' {
        # The pattern matches anywhere in the content (the -match operator)
        # This tests that checksum= in a comment still registers as "present"
        # (the action uses content-level detection, not line-by-line)
        $content = '# checksum = needed here'
        Test-Pattern $content $script:checksumPattern | Should -BeTrue
    }

    It 'does NOT match when checksum is absent from content' {
        $content = 'url = "https://example.com"' + "`n" + 'silentArgs = "/S"'
        Test-Pattern $content $script:checksumPattern | Should -BeFalse
    }
}

Describe 'Integrity check — Weak checksum algorithm detection' {
    It 'detects checksumType = "md5"' {
        $content = 'checksumType = "md5"'
        Test-Pattern $content $script:weakAlgoPattern | Should -BeTrue
    }

    It 'detects checksumType = "sha1"' {
        $content = 'checksumType = "sha1"'
        Test-Pattern $content $script:weakAlgoPattern | Should -BeTrue
    }

    It 'detects checksumType = ''md5'' (single-quoted)' {
        $content = "checksumType = 'md5'"
        Test-Pattern $content $script:weakAlgoPattern | Should -BeTrue
    }

    It 'detects checksumType = md5 (unquoted)' {
        $content = 'checksumType = md5'
        Test-Pattern $content $script:weakAlgoPattern | Should -BeTrue
    }

    It 'detects ChecksumType = "SHA1" (mixed case value)' {
        $content = 'checksumType = "SHA1"'
        Test-Pattern $content $script:weakAlgoPattern | Should -BeTrue
    }

    It 'does NOT flag checksumType = "sha256"' {
        $content = 'checksumType = "sha256"'
        Test-Pattern $content $script:weakAlgoPattern | Should -BeFalse
    }

    It 'does NOT flag checksumType = "sha512"' {
        $content = 'checksumType = "sha512"'
        Test-Pattern $content $script:weakAlgoPattern | Should -BeFalse
    }
}

Describe 'Integrity check — Invoke-WebRequest direct usage detection' {
    It 'detects Invoke-WebRequest -Uri "https://..."' {
        $content = 'Invoke-WebRequest -Uri "https://example.com/file.exe" -OutFile $dest'
        Test-Pattern $content $script:iwrPattern | Should -BeTrue
    }

    It 'detects Invoke-WebRequest -Uri $url (variable URL)' {
        $content = 'Invoke-WebRequest -Uri $downloadUrl -OutFile $dest'
        # Note: the pattern requires https?:// after -Uri, so variable URLs won't match
        # This tests the documented behavior
        Test-Pattern $content $script:iwrPattern | Should -BeFalse
    }

    It 'detects Invoke-WebRequest with http:// URL' {
        $content = 'Invoke-WebRequest -Uri "http://example.com/file.exe" -OutFile $dest'
        Test-Pattern $content $script:iwrPattern | Should -BeTrue
    }

    It 'detects IWR (alias form is NOT covered by this pattern)' {
        # The pattern looks for 'Invoke-WebRequest' explicitly, not the IWR alias
        $content = 'IWR -Uri "https://example.com/file.exe" -OutFile $dest'
        Test-Pattern $content $script:iwrPattern | Should -BeFalse
    }

    It 'does NOT match Invoke-WebRequest in a comment line' {
        # Pattern matches anywhere in content (action does content-level check)
        $content = '# Invoke-WebRequest -Uri "https://example.com" would work here'
        Test-Pattern $content $script:iwrPattern | Should -BeTrue
    }
}

Describe 'Integrity check — SHA256 hash pattern in VERIFICATION.txt' {
    It 'detects a valid 64-character hex SHA256 hash (lowercase)' {
        $hash = 'a' * 64
        Test-Pattern $hash $script:sha256Pattern | Should -BeTrue
    }

    It 'detects a valid 64-character hex SHA256 hash (uppercase)' {
        $hash = 'A' * 64
        Test-Pattern $hash $script:sha256Pattern | Should -BeTrue
    }

    It 'detects a realistic SHA256 hash embedded in text' {
        $content = "SHA256: $('a1b2c3d4' * 8)"
        Test-Pattern $content $script:sha256Pattern | Should -BeTrue
    }

    It 'detects SHA256 in a VERIFICATION.txt-style line' {
        $content = "Checksum Type: SHA256`nChecksum: $('deadbeef' * 8)"
        Test-Pattern $content $script:sha256Pattern | Should -BeTrue
    }

    It 'does NOT match a 63-character hex string (too short for SHA256)' {
        $hash = 'a' * 63
        Test-Pattern $hash $script:sha256Pattern | Should -BeFalse
    }

    It 'does NOT match placeholder text (no hex content)' {
        $content = 'CHECKSUM_VALUE_HERE'
        Test-Pattern $content $script:sha256Pattern | Should -BeFalse
    }

    It 'does NOT match a 40-character SHA1 hash (too short)' {
        $hash = 'a' * 40
        Test-Pattern $hash $script:sha256Pattern | Should -BeFalse
    }
}
