# PowerShell 脚本：卸载 rsync 和相关文件
# 功能：删除通过 xw-rsync.ps1 安装的所有 rsync 相关文件
# 包括：rsync.exe、msys-2.0.dll、msys-xxhash-0.dll 等依赖库
# 用途：方便开发者测试和用户完全卸载
$ErrorActionPreference = "Stop"

Write-Host "=== rsync Uninstaller ==="
Write-Host "This script will remove rsync and all dependencies installed by xw-rsync.ps1"
Write-Host ""

# 检测可能的安装目录（与安装脚本保持一致）
# 优先检查 Git 目录（推荐安装位置），然后检查用户目录（旧版本）
$GitPaths = @(
    "C:\Program Files\Git\usr\bin",
    "C:\Program Files (x86)\Git\usr\bin",
    "C:\awork\Git\usr\bin"
)
$UserPaths = @("$env:USERPROFILE\bin", "$env:USERPROFILE\.local\bin")
$PossibleDirs = $GitPaths + $UserPaths
$FoundInstallations = @()

foreach ($Dir in $PossibleDirs) {
    if (Test-Path "$Dir\rsync.exe") {
        $FoundInstallations += @{
            Path = $Dir
            Type = if ($Dir -like "*Git*usr*bin*") { "Git" } else { "User" }
        }
    }
}

if ($FoundInstallations.Count -eq 0) {
    Write-Host "No rsync installations found in standard locations:"
    foreach ($Dir in $PossibleDirs) {
        Write-Host "  - $Dir"
    }
    Write-Host ""
    Write-Host "rsync may not be installed or may be in a custom location."
    exit 0
}

# 检查管理员权限（如果需要卸载 Git 目录中的文件）
$GitInstallations = $FoundInstallations | Where-Object { $_.Type -eq "Git" }
if ($GitInstallations.Count -gt 0) {
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $IsAdmin) {
        Write-Host ""
        Write-Host "WARNING: Administrator privileges required to uninstall from Git directory!"
        Write-Host "Please run PowerShell as Administrator to remove rsync from Git installation."
        Write-Host ""
    }
}

# 显示找到的安装
Write-Host "Found rsync installations:"
foreach ($Installation in $FoundInstallations) {
    $Dir = $Installation.Path
    $Type = $Installation.Type
    Write-Host "  - $Dir [$Type installation]"
    if (Test-Path "$Dir\rsync.exe") {
        try {
            $Version = & "$Dir\rsync.exe" --version 2>$null | Select-Object -First 1
            if ($Version) {
                Write-Host "    Version: $Version"
            }
        }
        catch {
            Write-Host "    Version: Unable to determine"
        }
    }
    
    # 列出相关文件（与安装脚本安装的文件保持一致）
    $RelatedFiles = Get-ChildItem -Path $Dir -Filter "*rsync*" -ErrorAction SilentlyContinue
    $DllFiles = Get-ChildItem -Path $Dir -Filter "*.dll" -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match "(msys-iconv-2|msys-charset-1|msys-intl-8|msys-xxhash-0|msys-lz4-1|msys-zstd-1|msys-crypto-3)\.dll$"
    }
    
    if ($RelatedFiles.Count -gt 0 -or $DllFiles.Count -gt 0) {
        Write-Host "    Files to be removed:"
        foreach ($File in $RelatedFiles) {
            $Size = [math]::Round($File.Length / 1KB, 1)
            Write-Host "      $($File.Name) (${Size} KB)"
        }
        foreach ($File in $DllFiles) {
            $Size = [math]::Round($File.Length / 1KB, 1)
            Write-Host "      $($File.Name) (${Size} KB) [DLL]"
        }
    }
}

Write-Host ""
$Confirm = Read-Host "Do you want to proceed with uninstallation? (y/N)"
if ($Confirm -notmatch "^[Yy]") {
    Write-Host "Uninstallation cancelled."
    exit 0
}

# 执行卸载
Write-Host ""
Write-Host "Uninstalling rsync..."
$TotalRemoved = 0
$FailedRemovals = @()

foreach ($Installation in $FoundInstallations) {
    $Dir = $Installation.Path
    $Type = $Installation.Type
    Write-Host "Processing directory: $Dir [$Type installation]"

    # 只删除我们明确安装的 rsync 文件，不删除可能的 Git 原生文件
    $FilesToRemove = @()

    # 删除 rsync.exe（安全检查：检查是否有备份目录）
    $RsyncExe = Get-ChildItem -Path $Dir -Filter "rsync.exe" -ErrorAction SilentlyContinue
    if ($RsyncExe) {
        # 检查是否有备份目录（backup_* 格式），如果有说明是我们安装的
        $ParentDir = Split-Path $Dir -Parent
        $BackupDirs = Get-ChildItem -Path $ParentDir -Filter "backup_*" -Directory -ErrorAction SilentlyContinue
        if ($BackupDirs.Count -gt 0 -or $Type -eq "User") {
            $FilesToRemove += $RsyncExe
            Write-Host "  Found rsync.exe - will remove"
        } else {
            Write-Host "  Found rsync.exe but no backup found - asking for confirmation"
            $RemoveRsync = Read-Host "    Remove rsync.exe? (y/N)"
            if ($RemoveRsync -match "^[Yy]") {
                $FilesToRemove += $RsyncExe
            }
        }
    }

    # 只删除我们安装的 7 个核心 DLL（检查文件时间戳，只删除今天安装的）
    $Today = (Get-Date).Date
    $DllFiles = Get-ChildItem -Path $Dir -Filter "*.dll" -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match "(msys-iconv-2|msys-charset-1|msys-intl-8|msys-xxhash-0|msys-lz4-1|msys-zstd-1|msys-crypto-3)\.dll$" -and `
        $_.LastWriteTime.Date -eq $Today
    }
    $FilesToRemove += $DllFiles
    
    # 恢复备份文件（如果存在）
    $BackupDirs = Get-ChildItem -Path $Dir -Filter "backup_*" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($BackupDirs.Count -gt 0) {
        $LatestBackup = $BackupDirs[0]
        Write-Host "  Found backup directory: $($LatestBackup.Name)"
        $RestoreBackup = Read-Host "  Restore original files from backup? (Y/n)"
        if ($RestoreBackup -notmatch "^[Nn]") {
            try {
                $BackupFiles = Get-ChildItem -Path $LatestBackup.FullName -File
                foreach ($BackupFile in $BackupFiles) {
                    Copy-Item -Path $BackupFile.FullName -Destination $Dir -Force
                    Write-Host "  Restored: $($BackupFile.Name)"
                }
            }
            catch {
                Write-Host "  Failed to restore backup: $($_.Exception.Message)"
            }
        }
    }

    # 删除我们安装的文件
    foreach ($File in $FilesToRemove) {
        try {
            Remove-Item -Path $File.FullName -Force
            Write-Host "  Removed: $($File.Name)"
            $TotalRemoved++
        }
        catch {
            Write-Host "  Failed to remove: $($File.Name) - $($_.Exception.Message)"
            $FailedRemovals += $File.FullName
        }
    }
    
    # 检查目录是否为空，如果是则询问是否删除
    $RemainingFiles = Get-ChildItem -Path $Dir -ErrorAction SilentlyContinue
    if ($RemainingFiles.Count -eq 0) {
        Write-Host "  Directory $Dir is now empty."
        $RemoveDir = Read-Host "  Remove empty directory? (y/N)"
        if ($RemoveDir -match "^[Yy]") {
            try {
                Remove-Item -Path $Dir -Force
                Write-Host "  Removed directory: $Dir"
            }
            catch {
                Write-Host "  Failed to remove directory: $Dir - $($_.Exception.Message)"
            }
        }
    }
}

# 清理可能的临时文件（与新安装脚本产生的临时文件保持一致）
Write-Host ""
Write-Host "Cleaning up temporary files..."
$TempFiles = @(
    ".\rsync-*.pkg.tar.zst",
    ".\libiconv-*.pkg.tar.zst",
    ".\libintl-*.pkg.tar.zst",
    ".\libxxhash-*.pkg.tar.zst",
    ".\liblz4-*.pkg.tar.zst",
    ".\libzstd-*.pkg.tar.zst",
    ".\libopenssl-*.pkg.tar.zst",
    ".\temp_rsync_install",
    ".\zstd-portable.zip",
    ".\zstd-portable"
)

foreach ($Pattern in $TempFiles) {
    $Files = Get-ChildItem -Path $Pattern -ErrorAction SilentlyContinue
    foreach ($File in $Files) {
        try {
            if ($File.PSIsContainer) {
                Remove-Item -Path $File.FullName -Recurse -Force
            } else {
                Remove-Item -Path $File.FullName -Force
            }
            Write-Host "  Cleaned: $($File.Name)"
        }
        catch {
            Write-Host "  Failed to clean: $($File.Name)"
        }
    }
}

# 显示卸载结果
Write-Host ""
Write-Host "=== Uninstallation Summary ==="
Write-Host "Files removed: $TotalRemoved"

if ($FailedRemovals.Count -gt 0) {
    Write-Host "Failed to remove:"
    foreach ($File in $FailedRemovals) {
        Write-Host "  - $File"
    }
    Write-Host ""
    Write-Host "You may need to manually remove these files or run as administrator."
} else {
    Write-Host "All rsync files have been successfully removed."
}

Write-Host ""
Write-Host "Note: If you added the installation directory to your PATH environment variable,"
Write-Host "you may want to remove it manually from your system settings."
