# xw-rsync - Add rsync support to Git Bash to use the rsync utility in Windows environments.(为 Git Bash 添加 rsync 支持,在 Windows 环境中使用 rsync 工具)

[English](#english) | [简体中文](#简体中文)

---

## English

### What is it?
`xw-rsync.ps1` is a fully open-source PowerShell script designed to install the rsync tool in the Windows Git Bash environment. It ensures perfect compatibility between rsync and Git Bash, providing a simple and efficient way to use rsync on Windows.

### Problems it solves
- **Git for Windows doesn't include rsync by default**
- **`dup() in/out/err failed` errors**: Common fatal errors when manually installing rsync
- **I/O pipe incompatibility issues**: Conflicts between file descriptors and pipe handling mechanisms from different environments
- **Environment inconsistency compatibility problems**: SSH and rsync from different runtime environments
- **Missing dependency issues**: Most online tutorials are outdated with incomplete or mismatched dependency libraries

### Why 7 dependencies?
Through testing, we've found that using rsync 3.4.1 in the Git Bash environment requires 7 core dependencies:

- `msys-iconv-2.dll` + `msys-charset-1.dll` - for character encoding support
- `msys-intl-8.dll` - for internationalization support (needed by Git Bash tools)
- `msys-xxhash-0.dll` - for xxHash hashing algorithm
- `msys-lz4-1.dll` + `msys-zstd-1.dll` - for modern compression algorithms
- `msys-crypto-3.dll` - for OpenSSL 3.x encryption support

These dependencies are downloaded and extracted from the official MSYS2 repository, totaling around 5MB.

### Script Workflow

```
1. Environment Detection → 2. Permission Verification → 3. Tool Check → 4. Download and Install → 5. Test and Clean

├── Detect Git installation location
├── Verify administrator permissions
├── Check for extraction tools (prefer ZSTD, fallback to 7-Zip)
├── Download MSYS2 packages (rsync + 7 dependencies)
├── Backup existing files and install to Git/usr/bin/
├── Verify installation results and environment consistency
└── Clean temporary files (including temporary ZSTD downloads)
```

### Features
1. **One-click installation**: Automatically downloads and installs rsync and all dependencies
2. **Official sources**: Downloads from the official MSYS2 repository, ensuring security and reliability
3. **Environment compatibility**: Optimized specifically for the Git Bash environment
4. **Automatic backup**: Backs up existing files before installation, supports restoration
5. **Smart detection**: Dynamically identifies Git installation location, adapts to all Windows users
6. **No PATH configuration needed**: Installs directly to the Git directory, automatically recognized by Git Bash

### Quick Start

Open PowerShell as an administrator and copy-paste the following command to run:

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/zywe03/install-rsync-gitbash/main/xw-rsync.ps1'))
```

Verify installation:
```bash
# In Git Bash
rsync --version
```

### Why run with administrator privileges?
- **Administrator privileges required**: Installs to the Git system directory (`C:\Program Files\Git\usr\bin\`), ensuring rsync and related dependencies run correctly in Git Bash

### Installed Files
Installs to the Git system directory `C:\Program Files\Git\usr\bin\`:
- `rsync.exe` - rsync main program
- 7 required DLL dependency files

### Usage

```bash
# Basic usage
rsync --version

# File synchronization
rsync -av source/ user@host:/destination/

# With SSH key
rsync -av -e "ssh -i ~/.ssh/id_rsa" source/ user@host:/destination/
```

After installation, rsync usage is identical to standard Linux environments. For more usage, please refer to the [rsync official documentation](https://rsync.samba.org/).

### Project Files

```
xw-rsync/
├── xw-rsync.ps1           # Main installation script
├── test-rsync-env.sh      # Environment verification script (.sh version)
├── uninstall-rsync.ps1    # Uninstallation script (cleans up all rsync files downloaded by the script)
└── test-detection.ps1     # Environment verification script (.ps1 version)
```

### Other Script One-Click Run Commands

#### Environment Verification Script

Run .sh version using git bash:

```bash
bash <(curl -s https://raw.githubusercontent.com/zywe03/install-rsync-gitbash/main/test-rsync-env.sh)
```

Run .ps1 version using PowerShell:

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/zywe03/install-rsync-gitbash/main/test-detection.ps1'))
```

#### Uninstallation Script

Copy and paste the following command to run the uninstallation script:

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/zywe03/install-rsync-gitbash/main/uninstall-rsync.ps1'))
```

### 🤝 Technical Support

- **Other Open Source Projects:** <https://github.com/zywe03>
- **Author Homepage:** <https://zywe.de>
- **Issue Reporting:** [GitHub Issues](https://github.com/zywe03/install-rsync-gitbash/issues)
- **Submit PR:** [Pull Requests](https://github.com/zywe03/install-rsync-gitbash/pulls)

### 🙏 Acknowledgments

Thanks to all contributors and users who helped improve this project. Special thanks to:
- MSYS2 project for providing reliable package sources
- Git for Windows team for the excellent Git Bash environment
- Community members who provided feedback and testing

**⭐ If this project helps you, please give it a Star!**

---

---

## 简体中文

### 是什么？
`xw-rsync.ps1` 是一个完全开源的 PowerShell 脚本，为 Windows Git Bash 环境安装 rsync 工具，确保 rsync 与 Git Bash 的完美兼容，提供了一种简单而有效的方法来在 Windows 环境中使用 rsync 工具

### 解决的问题
- **Git for Windows 默认不包含 rsync 工具**
- **`dup() in/out/err failed` 错误**：手动安装 rsync 时常见的致命错误
- **I/O 管道不兼容问题**：不同环境的文件描述符和管道处理机制冲突
- **环境不一致导致的兼容性问题**：SSH 和 rsync 来自不同运行时环境
- **依赖缺失问题**：网上教程大多过时，依赖库不完整或版本不匹配

### 完整使用最新版rsync需要7 个依赖
我们通过实际测试发现完整使用 rsync 3.4.1 在 Git Bash 环境中需要 7 个核心依赖：

- `msys-iconv-2.dll` + `msys-charset-1.dll` - 字符编码支持
- `msys-intl-8.dll` - 国际化支持（Git Bash 工具需要）
- `msys-xxhash-0.dll` - xxHash 哈希算法
- `msys-lz4-1.dll` + `msys-zstd-1.dll` - 现代压缩算法
- `msys-crypto-3.dll` - OpenSSL 3.x 加密支持

依赖是从 MSYS2 官方仓库中下载并提取出来的，总大小约为 5MB。

### 脚本工作流程

```
1. 环境检测 → 2. 权限验证 → 3. 工具检查 → 4. 下载安装 → 5. 测试清理

├── 检测 Git 安装位置
├── 验证管理员权限
├── 检查解压工具（优先 ZSTD，备选 7-Zip）
├── 下载 MSYS2 官方包（rsync + 7个依赖）
├── 备份现有文件并安装到 Git/usr/bin/
├── 验证安装结果和环境一致性
└── 清理临时文件（包含临时下载的 ZSTD）
```

### 功能特点
1. **一键安装**：自动下载并安装 rsync 及所有依赖
2. **官方源**：从 MSYS2 官方仓库下载，安全可靠
3. **环境兼容**：专门针对 Git Bash 环境优化
4. **自动备份**：安装前备份现有文件，支持恢复
5. **智能检测**：动态识别 Git 安装位置，适配所有 Windows 用户
6. **无需配置 PATH**：直接安装到 Git 目录，Git Bash 自动识别

### 快速开始

请以管理员身份打开 PowerShell，然后复制并粘贴以下命令以一键运行：

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/zywe03/install-rsync-gitbash/main/xw-rsync.ps1'))
```

验证安装：
```bash
# 在 Git Bash 中
rsync --version
```

### 为什么需要管理员权限执行？
- **需要管理员权限**：安装到 Git 系统目录（`C:\Program Files\Git\usr\bin\`），这样做可以确保 rsync 和相关依赖能够在 Git Bash 中正确运行

### 安装的文件
安装到 Git 系统目录 `C:\Program Files\Git\usr\bin\`：
- `rsync.exe` - rsync 主程序
- 7 个必需的 DLL 依赖文件

### 使用方法

```bash
# 基本用法
rsync --version

# 文件同步
rsync -av source/ user@host:/destination/

# 配合 SSH 密钥
rsync -av -e "ssh -i ~/.ssh/id_rsa" source/ user@host:/destination/
```

安装完成后，rsync 的使用方法与标准 Linux 环境完全一致。更多用法请参考 [rsync 官方文档](https://rsync.samba.org/)。

### 项目文件

```
xw-rsync/
├── xw-rsync.ps1           # 主安装脚本
├── test-rsync-env.sh      # 环境验证脚本（.sh版本）
├── uninstall-rsync.ps1    # 卸载脚本（清理脚本下载的rsync全部文件）
└── test-detection.ps1     # 环境验证脚本（.ps1版本）
```

### 其他脚本一键运行命令

#### 环境验证脚本

使用 git 等 bash 运行 .sh 版本

```bash
bash <(curl -s https://raw.githubusercontent.com/zywe03/install-rsync-gitbash/main/test-rsync-env.sh)
```

使用 PowerShell 运行 .ps1 版本

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/zywe03/install-rsync-gitbash/main/test-detection.ps1'))
```

#### 卸载脚本

复制并粘贴以下命令以运行卸载脚本：

```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/zywe03/install-rsync-gitbash/main/uninstall-rsync.ps1'))
```

### 🤝 技术支持

- **其他开源项目：** <https://github.com/zywe03>
- **作者主页：** <https://zywe.de>
- **问题反馈：** [GitHub Issues](https://github.com/zywe03/install-rsync-gitbash/issues)
- **提交PR：** [Pull Requests](https://github.com/zywe03/install-rsync-gitbash/pulls)

### 🙏 致谢

感谢所有为改进此项目做出贡献的贡献者和用户。特别感谢：
- MSYS2 项目提供可靠的包源
- Git for Windows 团队提供优秀的 Git Bash 环境
- 提供反馈和测试的社区成员

**⭐ 如果这个项目对您有帮助，请给个 Star 支持一下！**

