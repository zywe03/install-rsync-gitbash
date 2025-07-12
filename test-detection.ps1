

Write-Host "=== Git Detection Test ==="


$GitPaths = @(
    "C:\Program Files\Git",
    "C:\Program Files (x86)\Git"
)

$GitFound = $false
foreach ($Path in $GitPaths) {
    if (Test-Path "$Path\usr\bin\bash.exe") {
        Write-Host "[OK] Found Git at: $Path"
        $GitFound = $true
        $DetectedGitPath = $Path
    } else {
        Write-Host "[NO] Not found: $Path"
    }
}


Write-Host ""
Write-Host "=== PATH Environment Check ==="
try {
    $GitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($GitCmd) {
        $GitExePath = $GitCmd.Source
        $PotentialGitPath = Split-Path (Split-Path $GitExePath -Parent) -Parent
        if (Test-Path "$PotentialGitPath\usr\bin\bash.exe") {
            Write-Host "[OK] Found Git via PATH at: $PotentialGitPath"
            if (-not $GitFound) {
                $GitFound = $true
                $DetectedGitPath = $PotentialGitPath
            }
        }
    } else {
        Write-Host "[NO] git command not found in PATH"
    }
}
catch {
    Write-Host "[NO] Error checking PATH for git"
}


Write-Host ""
Write-Host "=== Registry Check ==="
try {
    $RegPath = "HKLM:\SOFTWARE\GitForWindows"
    if (Test-Path $RegPath) {
        $InstallPath = Get-ItemProperty -Path $RegPath -Name "InstallPath" -ErrorAction SilentlyContinue
        if ($InstallPath -and (Test-Path "$($InstallPath.InstallPath)\usr\bin\bash.exe")) {
            Write-Host "[OK] Found Git via registry at: $($InstallPath.InstallPath)"
            if (-not $GitFound) {
                $GitFound = $true
                $DetectedGitPath = $InstallPath.InstallPath
            }
        }
    } else {
        Write-Host "[NO] Git registry key not found"
    }
}
catch {
    Write-Host "[NO] Error checking registry for Git"
}


Write-Host ""
Write-Host "=== Extraction Tools Check ==="


if (Get-Command zstd -ErrorAction SilentlyContinue) {
    Write-Host "[OK] ZSTD found in PATH"
} else {
    Write-Host "[NO] ZSTD not found in PATH"
}


$SevenZipPaths = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe"
)

$SevenZipFound = $false
foreach ($Path in $SevenZipPaths) {
    if (Test-Path $Path) {
        Write-Host "[OK] Found 7-Zip at: $Path"
        $SevenZipFound = $true
    } else {
        Write-Host "[NO] Not found: $Path"
    }
}


Write-Host ""
Write-Host "=== Current rsync Status ==="
if ($GitFound) {
    $InstallDir = "$DetectedGitPath\usr\bin"
    Write-Host "Checking in detected Git directory: $InstallDir"

    if (Test-Path "$InstallDir\rsync.exe") {
        Write-Host "[OK] rsync.exe found"


        try {
            $RsyncVersion = & "$InstallDir\rsync.exe" --version 2>$null | Select-Object -First 1
            Write-Host "  Version: $RsyncVersion"
        }
        catch {
            Write-Host "  [WARN] rsync.exe found but failed to run"
        }
    } else {
        Write-Host "[NO] rsync.exe not found"
    }
} else {
    Write-Host "[NO] Cannot check rsync status - Git not found"
}


Write-Host ""
Write-Host "=== Required DLLs Status ==="
if ($GitFound) {
    $RequiredDlls = @(
        "msys-iconv-2.dll",
        "msys-charset-1.dll",
        "msys-intl-8.dll",
        "msys-xxhash-0.dll",
        "msys-lz4-1.dll",
        "msys-zstd-1.dll",
        "msys-crypto-3.dll"
    )

    $FoundDlls = 0
    foreach ($Dll in $RequiredDlls) {
        if (Test-Path "$InstallDir\$Dll") {
            Write-Host "[OK] Found: $Dll"
            $FoundDlls++
        } else {
            Write-Host "[NO] Missing: $Dll"
        }
    }

    Write-Host ""
    Write-Host "DLL Summary: $FoundDlls/$($RequiredDlls.Count) required dependencies found"
} else {
    Write-Host "[NO] Cannot check DLLs - Git directory not found"
}


Write-Host ""
Write-Host "=== Administrator Privileges Check ==="
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($IsAdmin) {
    Write-Host "[OK] Running with administrator privileges"
} else {
    Write-Host "[NO] Not running with administrator privileges"
    Write-Host "  Note: Administrator privileges required for installation"
}


Write-Host ""
Write-Host "=== Detection Summary ==="
Write-Host "Git for Windows: $(if ($GitFound) { '[OK] Found' } else { '[NO] Not Found' })"
Write-Host "ZSTD Tool: $(if (Get-Command zstd -ErrorAction SilentlyContinue) { '[OK] Available' } else { '[NO] Not Available' })"
Write-Host "7-Zip Tool: $(if ($SevenZipFound) { '[OK] Available' } else { '[NO] Not Available' })"
Write-Host "Admin Rights: $(if ($IsAdmin) { '[OK] Available' } else { '[NO] Required' })"

if ($GitFound -and ($SevenZipFound -or (Get-Command zstd -ErrorAction SilentlyContinue)) -and $IsAdmin) {
    Write-Host ""
    Write-Host "[SUCCESS] System ready for rsync installation!"
} else {
    Write-Host ""
    Write-Host "[WARNING] Some requirements missing - installation may need additional steps"
}

Write-Host ""
Write-Host "=== Test Complete ==="
