# PowerShell 脚本：Git Bash rsync 完整安装器
# 直接安装 rsync 到 Git for Windows 目录以实现统一环境
# 确保 rsync 和 ssh 来自同一个 MSYS2 环境以避免 dup() 错误
$ErrorActionPreference = "Stop"

Write-Host "=== Git Bash rsync Complete Installer ==="
Write-Host "Installing rsync directly to Git for Windows (unified environment)"
Write-Host ""

# MSYS2 官方仓库
$RepoUrl = "https://repo.msys2.org/msys/x86_64"

# Git Bash 中 rsync 所需的包（7个核心依赖）
$RequiredPackages = @(
    @{ Name = "rsync"; Pattern = "^rsync-[0-9]+\.[0-9]+\.[0-9]+.*\.pkg\.tar\.zst$" },
    @{ Name = "libiconv"; Pattern = "^libiconv-[0-9]+\.[0-9]+.*\.pkg\.tar\.zst$" },
    @{ Name = "libintl"; Pattern = "^libintl-[0-9]+\.[0-9]+.*\.pkg\.tar\.zst$" },
    @{ Name = "libxxhash"; Pattern = "^libxxhash-[0-9]+\.[0-9]+\.[0-9]+.*\.pkg\.tar\.zst$" },
    @{ Name = "liblz4"; Pattern = "^liblz4-[0-9]+\.[0-9]+\.[0-9]+.*\.pkg\.tar\.zst$" },
    @{ Name = "libzstd"; Pattern = "^libzstd-[0-9]+\.[0-9]+\.[0-9]+.*\.pkg\.tar\.zst$" },
    @{ Name = "libopenssl"; Pattern = "^libopenssl-[0-9]+\.[0-9]+\.[0-9]+.*\.pkg\.tar\.zst$" }
)

# 检测 Git for Windows 安装位置
Write-Host "Detecting Git for Windows installation..."

# 尝试使用多种方法查找 Git
$GitPath = ""

# 方法1：检查常见安装路径
$GitPaths = @(
    "C:\Program Files\Git",
    "C:\Program Files (x86)\Git"
)

foreach ($Path in $GitPaths) {
    if (Test-Path "$Path\usr\bin\bash.exe") {
        $GitPath = $Path
        Write-Host "Found Git at: $GitPath"
        break
    }
}

# 方法2：尝试从 PATH 环境变量查找 Git
if (-not $GitPath) {
    Write-Host "Checking PATH for Git installation..."
    try {
        $GitCmd = Get-Command git -ErrorAction SilentlyContinue
        if ($GitCmd) {
            $GitExePath = $GitCmd.Source
            $PotentialGitPath = Split-Path (Split-Path $GitExePath -Parent) -Parent
            if (Test-Path "$PotentialGitPath\usr\bin\bash.exe") {
                $GitPath = $PotentialGitPath
                Write-Host "Found Git via PATH at: $GitPath"
            }
        }
    }
    catch {
        # 继续下一个方法
    }
}

# 方法3：检查注册表中的 Git 安装信息
if (-not $GitPath) {
    Write-Host "Checking registry for Git installation..."
    try {
        $RegPath = "HKLM:\SOFTWARE\GitForWindows"
        if (Test-Path $RegPath) {
            $InstallPath = Get-ItemProperty -Path $RegPath -Name "InstallPath" -ErrorAction SilentlyContinue
            if ($InstallPath -and (Test-Path "$($InstallPath.InstallPath)\usr\bin\bash.exe")) {
                $GitPath = $InstallPath.InstallPath
                Write-Host "Found Git via registry at: $GitPath"
            }
        }
    }
    catch {
        # 继续
    }
}

if (-not $GitPath) {
    Write-Host "Error: Git for Windows not found in any of the following locations:"
    foreach ($Path in $GitPaths) {
        Write-Host "  - $Path"
    }
    Write-Host "  - PATH environment variable"
    Write-Host "  - Windows registry"
    Write-Host ""
    Write-Host "Please install Git for Windows from https://gitforwindows.org/"
    exit 1
}

$InstallDir = "$GitPath\usr\bin"
Write-Host "Git for Windows found: $GitPath"
Write-Host "Installation directory: $InstallDir"

# 检查管理员权限（统一环境安装必需）
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $IsAdmin) {
    Write-Host ""
    Write-Host "ERROR: Administrator privileges are REQUIRED!"
    Write-Host ""
    Write-Host "Why Administrator privileges are needed:"
    Write-Host "  • rsync and ssh MUST be in the same MSYS2 environment (/usr/bin/)"
    Write-Host "  • This prevents 'dup() in/out/err failed' errors"
    Write-Host "  • Installing to user directory will cause environment conflicts"
    Write-Host ""
    Write-Host "Solution:"
    Write-Host "  1. Right-click PowerShell and select 'Run as Administrator'"
    Write-Host "  2. Re-run this script"
    Write-Host ""
    Write-Host "Installation cancelled."
    exit 1
}

# 检查是否已经安装
if ($InstallDir -and (Test-Path "$InstallDir\rsync.exe")) {
    $ExistingRsync = "$InstallDir\rsync.exe"
    Write-Host "rsync.exe already exists at $ExistingRsync"
    try {
        $ExistingVersion = & $ExistingRsync --version 2>$null | Select-Object -First 1
        if ($ExistingVersion) {
            Write-Host "Existing version: $ExistingVersion"
            $UserChoice = Read-Host "Do you want to reinstall? (y/N)"
            if ($UserChoice -notmatch "^[Yy]") {
                Write-Host "Installation cancelled. Existing rsync.exe kept."
                exit 0
            }
        }
    }
    catch {
        Write-Host "Existing rsync.exe appears to be corrupted, proceeding with reinstallation..."
    }
}

# 检查和准备解压工具（ZSTD 优先，7-Zip 备选）
Write-Host "Checking for extraction tools..."
$ZstdPath = ""
$DownloadedZstd = $false

# 检查 PATH 中的 zstd
if (Get-Command zstd -ErrorAction SilentlyContinue) {
    $ZstdPath = "zstd"
    Write-Host "Found existing zstd in PATH"
} else {
    Write-Host "ZSTD not found. Attempting to download ZSTD for temporary use..."

    # 尝试下载 ZSTD（带超时和 fallback）
    try {
        $ZstdZip = "zstd-temp.zip"
        $ZstdDir = "zstd-temp"

        # GitHub 源列表（带超时机制和 fallback）
        $ZstdUrls = @(
            "https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-v1.5.7-win64.zip"
        )

        $Downloaded = $false
        foreach ($ZstdUrl in $ZstdUrls) {
            try {
                Write-Host "  Downloading ZSTD from GitHub..."
                # 设置 15 秒超时
                Invoke-WebRequest -Uri $ZstdUrl -OutFile $ZstdZip -TimeoutSec 15
                $Downloaded = $true
                Write-Host "  Download successful"
                break
            }
            catch {
                Write-Host "  Download failed, network timeout or GitHub unavailable"
                Remove-Item -Path $ZstdZip -ErrorAction SilentlyContinue
            }
        }

        if (-not $Downloaded) {
            throw "Failed to download ZSTD - please check network connection or install ZSTD manually"
        }

        Write-Host "  Extracting ZSTD..."
        Expand-Archive -Path $ZstdZip -DestinationPath $ZstdDir -Force

        # 查找 zstd.exe
        $ZstdExe = Get-ChildItem -Path $ZstdDir -Name "zstd.exe" -Recurse | Select-Object -First 1
        if ($ZstdExe) {
            $ZstdPath = Join-Path $ZstdDir $ZstdExe
            $DownloadedZstd = $true
            Write-Host "  Successfully downloaded and extracted ZSTD"
        } else {
            throw "zstd.exe not found in downloaded package"
        }
    }
    catch {
        Write-Host "  Failed to download ZSTD. Checking for 7-Zip as alternative..."

        # 检查 7-Zip 作为替代方案
        $SevenZipPaths = @(
            "C:\Program Files\7-Zip\7z.exe",
            "C:\Program Files (x86)\7-Zip\7z.exe"
        )

        foreach ($Path in $SevenZipPaths) {
            if (Test-Path $Path) {
                $ZstdPath = $Path
                Write-Host "Found 7-Zip at: $Path"
                break
            }
        }
    }
}

if (-not $ZstdPath) {
    Write-Host "Error: No extraction tool available"
    Write-Host "Please install one of the following:"
    Write-Host "  1. ZSTD from https://github.com/facebook/zstd/releases"
    Write-Host "  2. 7-Zip from https://www.7-zip.org/"
    exit 1
}

# 获取仓库内容（带超时机制）
Write-Host "Fetching package list from MSYS2 repository..."
try {
    # 设置 15 秒超时
    $WebContent = Invoke-WebRequest -Uri $RepoUrl -UseBasicParsing -TimeoutSec 15
}
catch {
    Write-Host "Error: Failed to fetch package list from $RepoUrl"
    Write-Host "This may be due to network connectivity issues or repository unavailability"
    Write-Host "Please check your network connection and try again"
    exit 1
}

# 查找并下载所需的包
$DownloadedPackages = @()
foreach ($Package in $RequiredPackages) {
    Write-Host "Searching for latest $($Package.Name) package..."

    $LatestPkg = $WebContent.Links |
        Where-Object {
            $_.href -match $Package.Pattern -and
            $_.href -notlike "*.sig" -and
            $_.href -notlike "*-devel-*" -and
            $_.href -notlike "*-debug-*"
        } |
        Select-Object -ExpandProperty href |
        Sort-Object |
        Select-Object -Last 1

    if (-not $LatestPkg) {
        Write-Host "Error: Could not find $($Package.Name) package"
        exit 1
    }

    Write-Host "Found: $LatestPkg"
    $DownloadedPackages += $LatestPkg
}

# 下载所有包
Write-Host "Downloading packages..."
foreach ($PkgName in $DownloadedPackages) {
    if (-not (Test-Path $PkgName)) {
        $DownloadUrl = "$RepoUrl/$PkgName"
        Write-Host "  Downloading $PkgName..."
        try {
            # 设置 30 秒超时（包文件较大）
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $PkgName -TimeoutSec 30
        }
        catch {
            Write-Host "Error: Failed to download $PkgName"
            Write-Host "This may be due to network issues or repository unavailability"
            exit 1
        }
    } else {
        Write-Host "  Already exists: $PkgName"
    }
}

# 如果安装到 Git 目录，创建备份
if ($InstallDir -like "*Git*usr*bin*") {
    Write-Host "Creating backup of existing files..."
    $BackupDir = "$GitPath\usr\bin\backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    $FilesToBackup = @("ssh.exe", "rsync.exe", "ssh-keygen.exe", "ssh-agent.exe", "scp.exe", "sftp.exe")
    foreach ($File in $FilesToBackup) {
        $SourcePath = "$InstallDir\$File"
        if (Test-Path $SourcePath) {
            Copy-Item -Path $SourcePath -Destination "$BackupDir\$File" -Force
            Write-Host "  Backed up: $File"
        }
    }
    Write-Host "Backup directory: $BackupDir"
}

# 解压包
$TempDir = ".\temp_rsync_install"
if (Test-Path $TempDir) {
    Remove-Item -Path $TempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Write-Host "Extracting packages..."

$AllExtractedFiles = @()
foreach ($PkgFile in $DownloadedPackages) {
    Write-Host "  Extracting $PkgFile..."
    $PkgTempDir = "$TempDir\$($PkgFile -replace '\.pkg\.tar\.zst$', '')"
    New-Item -ItemType Directory -Path $PkgTempDir -Force | Out-Null

    try {
        if ($ZstdPath -eq "zstd" -or $DownloadedZstd) {
            # 使用 zstd 解压，然后用 tar 提取
            & $ZstdPath -d $PkgFile -o "$PkgTempDir\temp.tar"
            & tar -xf "$PkgTempDir\temp.tar" -C $PkgTempDir
            Remove-Item "$PkgTempDir\temp.tar" -ErrorAction SilentlyContinue
        } else {
            # 使用 7-Zip 进行解压和提取
            & $ZstdPath x $PkgFile -o"$PkgTempDir" -y | Out-Null
            $TarFile = Get-ChildItem -Path $PkgTempDir -Filter "*.tar" | Select-Object -First 1
            if ($TarFile) {
                & $ZstdPath x $TarFile.FullName -o"$PkgTempDir" -y | Out-Null
            }
        }

        # 收集解压的文件
        $ExtractedFiles = Get-ChildItem -Path $PkgTempDir -Recurse -File
        $AllExtractedFiles += $ExtractedFiles

    }
    catch {
        Write-Host "Error: Failed to extract $PkgFile"
        Write-Host "Error details: $($_.Exception.Message)"
        exit 1
    }
}

# 查找 rsync.exe 和所有必需文件
Write-Host "Collecting rsync.exe and dependency files..."
$RsyncExe = $AllExtractedFiles | Where-Object { $_.Name -eq "rsync.exe" } | Select-Object -First 1
if (-not $RsyncExe) {
    Write-Host "Error: Failed to find rsync.exe in extracted files"
    exit 1
}

# SSH 可执行文件已经在 Git 中 - 我们不需要安装它们
# 只需验证它们在目标目录中存在
$SshExecutables = @()
$SshExeNames = @("ssh.exe", "ssh-keygen.exe", "ssh-agent.exe", "ssh-add.exe", "scp.exe", "sftp.exe")
foreach ($ExeName in $SshExeNames) {
    if (Test-Path "$InstallDir\$ExeName") {
        $SshExecutables += $ExeName
    }
}

# 查找所需的 DLL 文件（rsync 的 7 个核心依赖）
$RequiredDlls = $AllExtractedFiles | Where-Object {
    $_.Extension -eq ".dll" -and
    $_.Name -match "(msys-iconv-2|msys-charset-1|msys-intl-8|msys-xxhash-0|msys-lz4-1|msys-zstd-1|msys-crypto-3)\.dll$"
}

Write-Host "Found rsync.exe: $($RsyncExe.Name)"
Write-Host "Found $($SshExecutables.Count) existing SSH executables:"
foreach ($exe in $SshExecutables) {
    Write-Host "  $exe"
}
Write-Host "Found $($RequiredDlls.Count) dependency DLLs:"
foreach ($dll in $RequiredDlls) {
    Write-Host "  $($dll.Name)"
}

# 安装文件到目标目录
Write-Host "Installing files to $InstallDir..."
try {
    # 安装 rsync.exe
    Copy-Item -Path $RsyncExe.FullName -Destination "$InstallDir\rsync.exe" -Force
    Write-Host "  Installed: rsync.exe"

    # SSH 可执行文件已经在 Git 中 - 无需重新安装
    Write-Host "  SSH executables already present in Git installation"

    # 安装所有必需的 DLL 文件
    foreach ($Dll in $RequiredDlls) {
        Copy-Item -Path $Dll.FullName -Destination "$InstallDir\$($Dll.Name)" -Force
        Write-Host "  Installed: $($Dll.Name)"
    }
}
catch {
    Write-Host "Error: Failed to copy files to $InstallDir"
    Write-Host "Error details: $($_.Exception.Message)"
    exit 1
}

# 测试安装
Write-Host "Testing rsync installation..."
if (Test-Path "$InstallDir\rsync.exe") {
    try {
        $VersionOutput = & "$InstallDir\rsync.exe" --version 2>&1 | Select-Object -First 1
        Write-Host "✓ rsync version: $VersionOutput"
        Write-Host "✓ Installation successful!"
    }
    catch {
        Write-Host "⚠ rsync installed but failed to run"
        Write-Host "Error: $($_.Exception.Message)"
    }
} else {
    Write-Host "✗ Error: rsync.exe not found in $InstallDir"
    exit 1
}

# 测试环境一致性（如果是 Git 安装）
if ($InstallDir -like "*Git*usr*bin*") {
    Write-Host ""
    Write-Host "Testing environment consistency..."
    $TestScript = @"
echo "=== Environment Test ==="
echo "rsync path: `$(which rsync)"
echo "ssh path: `$(which ssh)"
if [[ "`$(which ssh)" == "/usr/bin/ssh" && "`$(which rsync)" == "/usr/bin/rsync" ]]; then
  echo "✓ Environment consistent: both from /usr/bin/"
else
  echo "⚠ Environment inconsistent"
fi
"@

    $TestFile = "$env:TEMP\test_env.sh"
    $TestScript | Out-File -FilePath $TestFile -Encoding UTF8

    # 转换为 LF 行结束符
    $Content = Get-Content $TestFile -Raw
    $Content = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($TestFile, $Content)

    try {
        & "$GitPath\bin\bash.exe" $TestFile
    } catch {
        Write-Host "Environment test failed, but installation may still work"
    }

    Remove-Item $TestFile -ErrorAction SilentlyContinue
}

# 清理
Write-Host ""
Write-Host "Cleaning up temporary files..."
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
foreach ($PkgFile in $DownloadedPackages) {
    Remove-Item -Path $PkgFile -ErrorAction SilentlyContinue
}

# 清理下载的 ZSTD（如果有的话）
if ($DownloadedZstd) {
    Write-Host "Cleaning up downloaded ZSTD..."
    Remove-Item -Path "zstd-temp.zip" -ErrorAction SilentlyContinue
    Remove-Item -Path "zstd-temp" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  Downloaded ZSTD cleaned up (system remains clean)"
}

# 安装总结
Write-Host ""
Write-Host "=== Installation Complete ==="
Write-Host "Installation directory: $InstallDir"

if ($InstallDir -like "*Git*usr*bin*") {
    Write-Host ""
    Write-Host "✓ rsync installed directly to Git for Windows!"
    Write-Host "✓ rsync and ssh now come from the same MSYS2 environment"
    Write-Host "✓ This should resolve 'dup() in/out/err failed' errors"
    Write-Host ""
    Write-Host "Usage in Git Bash:"
    Write-Host "  rsync [options]  # Direct command"
    Write-Host ""
    Write-Host "Test commands:"
    Write-Host "  which rsync  # Should show /usr/bin/rsync"
    Write-Host "  which ssh    # Should show /usr/bin/ssh"
    Write-Host "  rsync --version"
}

Write-Host ""
Write-Host "Installation complete!"
