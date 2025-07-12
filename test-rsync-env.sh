#!/bin/bash

# 测试 rsync 环境一致性脚本
# 用于验证 SSH 和 rsync 是否来自同一个 MSYS2 环境
# 全面检测安装效果和环境配置

echo "=== rsync Environment Consistency Test ==="
echo ""

# 检查 rsync 是否存在
if ! command -v rsync &> /dev/null; then
    echo "❌ rsync not found!"
    echo "Please install rsync first using the installation script"
    exit 1
fi

# 检查 ssh 是否存在
if ! command -v ssh &> /dev/null; then
    echo "❌ ssh not found!"
    echo "Please ensure Git for Windows is properly installed"
    exit 1
fi

# 获取路径信息
RSYNC_PATH=$(which rsync)
SSH_PATH=$(which ssh)

echo "Detected paths:"
echo "  rsync: $RSYNC_PATH"
echo "  ssh:   $SSH_PATH"
echo ""

# 检查版本信息
echo "Version information:"
RSYNC_VERSION=$(rsync --version 2>/dev/null | head -n 1)
SSH_VERSION=$(ssh -V 2>&1 | head -n 1)
echo "  rsync: $RSYNC_VERSION"
echo "  ssh:   $SSH_VERSION"
echo ""

# 基本功能测试
echo "Basic functionality test:"
if rsync --help &> /dev/null; then
    echo "✅ rsync help command works"
else
    echo "❌ rsync help command failed"
    CONSISTENT=false
fi

# 测试 rsync 是否能正常执行
if rsync --version &> /dev/null; then
    echo "✅ rsync version command works"
else
    echo "❌ rsync version command failed"
    CONSISTENT=false
fi
echo ""

# 环境一致性检查
echo "Environment consistency check:"
if [[ "$SSH_PATH" == "/usr/bin/ssh" && "$RSYNC_PATH" == "/usr/bin/rsync" ]]; then
    echo "✅ Environment consistent: both SSH and rsync from /usr/bin/"
    echo "✅ This should prevent dup() errors"
    CONSISTENT=true
elif [[ "$SSH_PATH" == *"/usr/bin/ssh" && "$RSYNC_PATH" == *"/usr/bin/rsync" ]]; then
    echo "✅ Environment consistent: both SSH and rsync from usr/bin/"
    echo "✅ This should prevent dup() errors"
    CONSISTENT=true
else
    echo "❌ Environment inconsistent!"
    echo "❌ This may cause 'dup() in/out/err failed' errors"
    echo ""
    echo "Solution:"
    echo "1. Run PowerShell as Administrator"
    echo "2. Re-run xw-rsync.ps1 to install to Git directory"
    CONSISTENT=false
fi

echo ""

# 依赖检查
echo "Dependency library check:"
# 获取 rsync 所在目录，处理 Windows 路径
if [[ "$RSYNC_PATH" == /usr/bin/rsync ]]; then
    # Git Bash 环境，转换为实际 Windows 路径
    GIT_ROOT=$(cd /usr && pwd -W 2>/dev/null || echo "C:/Program Files/Git/usr")
    RSYNC_DIR="$GIT_ROOT/bin"
else
    RSYNC_DIR=$(dirname "$RSYNC_PATH")
fi

echo "Checking directory: $RSYNC_DIR"
REQUIRED_DLLS=("msys-iconv-2.dll" "msys-charset-1.dll" "msys-intl-8.dll" "msys-xxhash-0.dll" "msys-lz4-1.dll" "msys-zstd-1.dll" "msys-crypto-3.dll")

MISSING_DLLS=0
for dll in "${REQUIRED_DLLS[@]}"; do
    if [[ -f "$RSYNC_DIR/$dll" ]]; then
        echo "✅ $dll"
    else
        echo "❌ $dll (missing)"
        CONSISTENT=false
        ((MISSING_DLLS++))
    fi
done

echo ""
echo "Dependency summary: $((${#REQUIRED_DLLS[@]} - MISSING_DLLS))/${#REQUIRED_DLLS[@]} required DLLs found"
echo ""

# 高级功能测试
echo "Advanced functionality test:"
# 测试 rsync 的基本同步功能（dry-run）
TEST_DIR="/tmp/rsync_test_$$"
mkdir -p "$TEST_DIR/source" "$TEST_DIR/dest" 2>/dev/null
echo "test file" > "$TEST_DIR/source/test.txt" 2>/dev/null

if rsync -av --dry-run "$TEST_DIR/source/" "$TEST_DIR/dest/" &> /dev/null; then
    echo "✅ rsync dry-run test passed"
else
    echo "❌ rsync dry-run test failed"
    CONSISTENT=false
fi

# 清理测试文件
rm -rf "$TEST_DIR" 2>/dev/null
echo ""

# 最终结果
if [[ "$CONSISTENT" == "true" ]]; then
    echo "🎉 Environment configuration is correct! rsync should work properly"
    echo ""
    echo "Recommended tests:"
    echo "  rsync --version"
    echo "  rsync -av --dry-run ./source/ user@host:/destination/"
    echo "  rsync -av --dry-run ./source/ ./destination/"
    echo ""
    echo "✅ Installation verification: PASSED"
else
    echo "⚠️  Environment configuration has issues, may encounter errors"
    echo ""
    echo "Recommendations:"
    echo "1. Re-install rsync to Git directory with administrator privileges"
    echo "2. Ensure all dependency libraries are properly installed"
    echo ""
    echo "❌ Installation verification: FAILED"
fi

echo ""
echo "Test completed."
