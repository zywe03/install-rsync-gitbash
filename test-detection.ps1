# 测试 xw-rsync.ps1 的检测逻辑
# 全面检测系统环境和工具可用性

Write-Host "=== Git Detection Test ==="

# 方法1：检查常见路径

$GitPaths = @(
    "C:\Program Files\Git",
    "C:\Program Files (x86)\Git"
)

$GitFound = $false
foreach ($Path in $GitPaths) {
    if (Test-Path "$Path\usr\bin\bash.exe") {
        Write-Host "✓ Found Git at: $Path"
        $GitFound = $true
        $DetectedGitPath = $Path
    } else {
        Write-Host "✗ Not found: $Path"
    }
}

# 方法2：检查 PATH 环境变量

Write-Host ""
Write-Host "=== PATH Environment Check ==="
try {
    $GitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($GitCmd) {
        $GitExePath = $GitCmd.Source
        $PotentialGitPath = Split-Path (Split-Path $GitExePath -Parent) -Parent
        if (Test-Path "$PotentialGitPath\usr\bin\bash.exe") {
            Write-Host "✓ Found Git via PATH at: $PotentialGitPath"
            if (-not $GitFound) {
                $GitFound = $true
                $DetectedGitPath = $PotentialGitPath
            }
        }
    } else {
        Write-Host "✗ git command not found in PATH"
    }
}
catch {
    Write-Host "✗ Error checking PATH for git"
}

# 方法3：检查注册表

Write-Host ""
Write-Host "=== Registry Check ==="
try {
    $RegPath = "HKLM:\SOFTWARE\GitForWindows"
    if (Test-Path $RegPath) {
        $InstallPath = Get-ItemProperty -Path $RegPath -Name "InstallPath" -ErrorAction SilentlyContinue
        if ($InstallPath -and (Test-Path "$($InstallPath.InstallPath)\usr\bin\bash.exe")) {
            Write-Host "✓ Found Git via registry at: $($InstallPath.InstallPath)"
            if (-not $GitFound) {
                $GitFound = $true
                $DetectedGitPath = $InstallPath.InstallPath
            }
        }
    } else {
        Write-Host "✗ Git registry key not found"
    }
}
catch {
    Write-Host "✗ Error checking registry for Git"
}

# 解压工具检测
Write-Host ""
Write-Host "=== Extraction Tools Check ==="

# 检查 ZSTD
if (Get-Command zstd -ErrorAction SilentlyContinue) {
    Write-Host "✓ ZSTD found in PATH"
} else {
    Write-Host "✗ ZSTD not found in PATH"
}

# 检查 7-Zip
$SevenZipPaths = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe"
)

$SevenZipFound = $false
foreach ($Path in $SevenZipPaths) {
    if (Test-Path $Path) {
        Write-Host "✓ Found 7-Zip at: $Path"
        $SevenZipFound = $true
    } else {
        Write-Host "✗ Not found: $Path"
    }
}

# 当前 rsync 状态检查
Write-Host ""
Write-Host "=== Current rsync Status ==="
if ($GitFound) {
    $InstallDir = "$DetectedGitPath\usr\bin"
    Write-Host "Checking in detected Git directory: $InstallDir"

    if (Test-Path "$InstallDir\rsync.exe") {
        Write-Host "✓ rsync.exe found"

        # 检查版本
        try {
            $RsyncVersion = & "$InstallDir\rsync.exe" --version 2>$null | Select-Object -First 1
            Write-Host "  Version: $RsyncVersion"
        }
        catch {
            Write-Host "  ⚠ rsync.exe found but failed to run"
        }
    } else {
        Write-Host "✗ rsync.exe not found"
    }
} else {
    Write-Host "✗ Cannot check rsync status - Git not found"
}

# 依赖库检查
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
            Write-Host "✓ Found: $Dll"
            $FoundDlls++
        } else {
            Write-Host "✗ Missing: $Dll"
        }
    }

    Write-Host ""
    Write-Host "DLL Summary: $FoundDlls/$($RequiredDlls.Count) required dependencies found"
} else {
    Write-Host "✗ Cannot check DLLs - Git directory not found"
}

# 管理员权限检查
Write-Host ""
Write-Host "=== Administrator Privileges Check ==="
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($IsAdmin) {
    Write-Host "✓ Running with administrator privileges"
} else {
    Write-Host "✗ Not running with administrator privileges"
    Write-Host "  Note: Administrator privileges required for installation"
}

# 总结
Write-Host ""
Write-Host "=== Detection Summary ==="
Write-Host "Git for Windows: $(if ($GitFound) { '✓ Found' } else { '✗ Not Found' })"
Write-Host "ZSTD Tool: $(if (Get-Command zstd -ErrorAction SilentlyContinue) { '✓ Available' } else { '✗ Not Available' })"
Write-Host "7-Zip Tool: $(if ($SevenZipFound) { '✓ Available' } else { '✗ Not Available' })"
Write-Host "Admin Rights: $(if ($IsAdmin) { '✓ Available' } else { '✗ Required' })"

if ($GitFound -and ($SevenZipFound -or (Get-Command zstd -ErrorAction SilentlyContinue)) -and $IsAdmin) {
    Write-Host ""
    Write-Host "🎉 System ready for rsync installation!"
} else {
    Write-Host ""
    Write-Host "⚠️  Some requirements missing - installation may need additional steps"
}

Write-Host ""
Write-Host "=== Test Complete ==="
