#!/bin/bash
# ==============================================================================
# LabelLoad DEB 打包脚本
# ==============================================================================
# 创建符合 Debian 标准的 .deb 安装包
#
# 用法: ./packaging/build_deb.sh [选项]
#   --cpu-only    仅 CPU 推理 (不含 CUDA provider，包更小)
#   --no-ort      不打包 ONNX Runtime (依赖系统安装)
#   --version X   指定版本号 (默认读取 pubspec.yaml)
#
# 输出:
#   GPU: label-load_版本_gpu_amd64.deb (~120MB)
#   CPU: label-load_版本_amd64.deb (~18MB)
#
# 注意: GPU 版本用户需自行安装 NVIDIA CUDA Toolkit
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# 从 pubspec.yaml 读取版本号（去掉 build metadata）
read_pubspec_version() {
    local pubspec="$PROJECT_DIR/pubspec.yaml"
    local version=""

    if [[ -f "$pubspec" ]]; then
        version=$(awk -F': *' '/^version:/ {print $2; exit}' "$pubspec")
    fi

    version="${version%%+*}"
    if [[ -z "$version" ]]; then
        version="0.0.0"
    fi

    echo "$version"
}

# ==============================================================================
# 配置
# ==============================================================================

APP_NAME="label-load"
APP_DISPLAY_NAME="Label Load"
DEFAULT_VERSION="$(read_pubspec_version)"
VERSION="$DEFAULT_VERSION"
MAINTAINER="Label Load Developers"
DESCRIPTION="图像标注工具，支持 YOLO 格式和 AI 辅助标注"
HOMEPAGE="https://github.com/label-load/label-load"
ARCH="amd64"

# 打包选项
BUNDLE_ORT=true
BUNDLE_GPU=true

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-ort)
            BUNDLE_ORT=false
            ;;
        --cpu-only)
            BUNDLE_GPU=false
            ;;
        --version)
            shift
            if [[ -n "${1:-}" ]]; then
                VERSION="$1"
            else
                echo "错误: --version 需要指定版本号"
                exit 1
            fi
            ;;
        *)
            echo "未知参数: $1"
            echo "用法: $0 [--cpu-only] [--no-ort] [--version X]"
            exit 1
            ;;
    esac
    shift
done

# ==============================================================================
# 颜色和日志
# ==============================================================================

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[DONE]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step()    { echo -e "${CYAN}  →${NC} $1"; }

# ==============================================================================
# 目录设置
# ==============================================================================

BUILD_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"
DEB_ROOT="$PROJECT_DIR/build/deb"
ORT_LIB_DIR="/usr/local/lib"

# DEB 文件名区分 GPU/CPU 版本
if [[ "$BUNDLE_GPU" == "true" ]]; then
    PKG_SUFFIX="_gpu"
    BUILD_TYPE="GPU"
else
    PKG_SUFFIX=""
    BUILD_TYPE="CPU"
fi

PKG_DIR="$DEB_ROOT/${APP_NAME}_${VERSION}${PKG_SUFFIX}_${ARCH}"

# ==============================================================================
# 预检查
# ==============================================================================

echo ""
echo "========================================"
echo -e "  ${BLUE}Label Load DEB 打包${NC}"
echo "========================================"
echo "  版本: $VERSION"
echo "  架构: $ARCH"
echo "  类型: $BUILD_TYPE"
echo "  打包 ORT: $BUNDLE_ORT"
echo "========================================"
echo ""

if [[ ! -f "$BUILD_DIR/label_load" ]]; then
    echo "错误: 未找到构建产物"
    echo "请先运行: flutter build linux --release"
    exit 1
fi

# ==============================================================================
# 创建目录结构
# ==============================================================================

log_info "创建目录结构..."
rm -rf "$DEB_ROOT"
mkdir -p "$PKG_DIR"

# 创建标准 Linux 目录结构
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/opt/$APP_NAME"
mkdir -p "$PKG_DIR/opt/$APP_NAME/lib"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/applications"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/64x64/apps"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/48x48/apps"
mkdir -p "$PKG_DIR/usr/share/doc/$APP_NAME"

# ==============================================================================
# 复制应用文件
# ==============================================================================

log_info "复制应用文件..."

log_step "复制主程序"
cp "$BUILD_DIR/label_load" "$PKG_DIR/opt/$APP_NAME/"

log_step "复制数据和库"
cp -r "$BUILD_DIR/data" "$PKG_DIR/opt/$APP_NAME/"
cp -r "$BUILD_DIR/lib" "$PKG_DIR/opt/$APP_NAME/"

# ==============================================================================
# 复制许可证和第三方声明
# ==============================================================================

log_info "复制许可证和第三方声明..."

if [[ -f "$PROJECT_DIR/LICENSE" ]]; then
    cp "$PROJECT_DIR/LICENSE" "$PKG_DIR/usr/share/doc/$APP_NAME/copyright"
    log_step "已复制: LICENSE"
else
    log_warn "未找到 LICENSE"
fi

if [[ -f "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" ]]; then
    cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$PKG_DIR/usr/share/doc/$APP_NAME/THIRD_PARTY_NOTICES"
    log_step "已复制: THIRD_PARTY_NOTICES"
else
    log_warn "未找到 THIRD_PARTY_NOTICES.md"
fi

# ==============================================================================
# 复制 ONNX Runtime 库
# ==============================================================================

if [[ "$BUNDLE_ORT" == "true" ]]; then
    log_info "打包 ONNX Runtime 库..."
    
    # 复制核心 ORT 库
    for lib in "$ORT_LIB_DIR"/libonnxruntime.so*; do
        if [[ -e "$lib" ]]; then
            libname=$(basename "$lib")
            # 跳过 provider 库（后面单独处理）
            if [[ "$libname" != *"providers"* ]]; then
                cp -L "$lib" "$PKG_DIR/opt/$APP_NAME/lib/"
                log_step "已复制: $libname"
            fi
        fi
    done
    
    # 复制 providers_shared（始终需要）
    if [[ -e "$ORT_LIB_DIR/libonnxruntime_providers_shared.so" ]]; then
        cp -L "$ORT_LIB_DIR/libonnxruntime_providers_shared.so" "$PKG_DIR/opt/$APP_NAME/lib/"
        log_step "已复制: libonnxruntime_providers_shared.so"
    fi
    
    # 创建符号链接
    cd "$PKG_DIR/opt/$APP_NAME/lib/"
    REAL_LIB=$(ls libonnxruntime.so.*.*.* 2>/dev/null | head -1 || true)
    if [[ -n "$REAL_LIB" ]]; then
        MAJOR_VER=$(echo "$REAL_LIB" | sed 's/libonnxruntime.so.\([0-9]*\).*/\1/')
        ln -sf "$REAL_LIB" "libonnxruntime.so.$MAJOR_VER" 2>/dev/null || true
        ln -sf "libonnxruntime.so.$MAJOR_VER" "libonnxruntime.so" 2>/dev/null || true
    fi
    cd "$PROJECT_DIR"
    
    # GPU 库
    if [[ "$BUNDLE_GPU" == "true" ]]; then
        for pattern in "libonnxruntime_providers_cuda.so" "libonnxruntime_providers_tensorrt.so"; do
            if [[ -e "$ORT_LIB_DIR/$pattern" ]]; then
                cp -L "$ORT_LIB_DIR/$pattern" "$PKG_DIR/opt/$APP_NAME/lib/"
                log_step "已复制 GPU 库: $pattern"
            fi
        done
    else
        log_step "跳过 GPU 库 (--cpu-only)"
    fi
fi

# ==============================================================================
# 创建启动脚本
# ==============================================================================

log_info "创建启动脚本..."

cat > "$PKG_DIR/opt/$APP_NAME/label-load" << 'LAUNCHER'
#!/bin/bash
# ==============================================================================
# Label Load 启动脚本
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 设置库路径
export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:${LD_LIBRARY_PATH:-}"

# GTK 环境（抑制无关警告）
export GTK_IM_MODULE="${GTK_IM_MODULE:-gtk-im-context-simple}"
export NO_AT_BRIDGE=1
export GTK_A11Y=none

# 运行应用
exec "$SCRIPT_DIR/label_load" "$@"
LAUNCHER
chmod +x "$PKG_DIR/opt/$APP_NAME/label-load"

# 创建 /usr/bin wrapper
cat > "$PKG_DIR/usr/bin/$APP_NAME" << 'WRAPPER'
#!/bin/bash
exec /opt/label-load/label-load "$@"
WRAPPER
chmod +x "$PKG_DIR/usr/bin/$APP_NAME"

# ==============================================================================
# 处理图标
# ==============================================================================

log_info "处理图标..."

ICON_SRC="$PROJECT_DIR/assets/icon.png"
if [[ -f "$ICON_SRC" ]]; then
    if command -v convert &> /dev/null; then
        convert "$ICON_SRC" -resize 256x256 "$PKG_DIR/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"
        convert "$ICON_SRC" -resize 128x128 "$PKG_DIR/usr/share/icons/hicolor/128x128/apps/$APP_NAME.png"
        convert "$ICON_SRC" -resize 64x64 "$PKG_DIR/usr/share/icons/hicolor/64x64/apps/$APP_NAME.png"
        convert "$ICON_SRC" -resize 48x48 "$PKG_DIR/usr/share/icons/hicolor/48x48/apps/$APP_NAME.png"
        log_step "生成多尺寸图标"
    else
        cp "$ICON_SRC" "$PKG_DIR/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"
        log_step "复制原始图标到 256x256"
    fi
    cp "$ICON_SRC" "$PKG_DIR/opt/$APP_NAME/icon.png"
else
    log_warn "未找到图标文件: $ICON_SRC"
fi

# ==============================================================================
# 创建 .desktop 文件
# ==============================================================================

log_info "创建 .desktop 文件..."

cat > "$PKG_DIR/usr/share/applications/$APP_NAME.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=$APP_DISPLAY_NAME
Comment=$DESCRIPTION
Exec=/opt/$APP_NAME/label-load %F
Icon=$APP_NAME
Terminal=false
Categories=Graphics;ImageProcessing;
MimeType=image/png;image/jpeg;image/bmp;image/gif;
Keywords=label;annotation;yolo;image;ai;
StartupWMClass=label_load
DESKTOP

# ==============================================================================
# 创建 DEBIAN 控制文件
# ==============================================================================

log_info "创建 DEBIAN 控制文件..."

# 依赖包列表
DEPS=(
    "libgtk-3-0"
    "libglib2.0-0"
    "libcairo2"
    "libpango-1.0-0"
    "libgdk-pixbuf-2.0-0"
    "libx11-6"
    "libxext6"
    "libxrender1"
    "libxinerama1"
    "libxi6"
    "libxrandr2"
    "libxcursor1"
    "libxcomposite1"
    "libxdamage1"
    "libxfixes3"
    "libatk1.0-0"
    "libatk-bridge2.0-0"
    "libepoxy0"
    "libfontconfig1"
    "libfreetype6"
    "libharfbuzz0b"
    "libpangocairo-1.0-0"
    "libpangoft2-1.0-0"
    "libpixman-1-0"
    "libpng16-16"
    "libjpeg62-turbo | libjpeg-turbo8"
    "libwayland-client0"
    "libwayland-cursor0"
    "libwayland-egl1"
    "libxkbcommon0"
    "zlib1g"
)

# 生成依赖字符串
DEPENDS=""
for dep in "${DEPS[@]}"; do
    if [[ -n "$DEPENDS" ]]; then
        DEPENDS="$DEPENDS, $dep"
    else
        DEPENDS="$dep"
    fi
done

# 计算安装大小 (KB)
INSTALLED_SIZE=$(du -sk "$PKG_DIR" | cut -f1)

# control 文件
cat > "$PKG_DIR/DEBIAN/control" << CONTROL
Package: $APP_NAME
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $ARCH
Depends: $DEPENDS
Installed-Size: $INSTALLED_SIZE
Maintainer: $MAINTAINER
Homepage: $HOMEPAGE
Description: $DESCRIPTION
 Label Load 是一款现代化的图像标注工具，专为机器学习
 数据准备而设计。支持 YOLO 格式标注，内置 AI 辅助
 标注功能，提供流畅的标注体验。
 .
 特性:
  - 支持 YOLO 格式导入/导出
  - AI 辅助自动标注 (YOLOv8/YOLOv8-Pose)
  - 多种标注类型（矩形框、关键点、多边形）
  - 完全可自定义的快捷键
  - 批量处理工具
CONTROL

# postinst 脚本
cat > "$PKG_DIR/DEBIAN/postinst" << 'POSTINST'
#!/bin/bash
set -e

# 更新图标缓存
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

# 更新桌面数据库
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi

# 更新 ldconfig
ldconfig 2>/dev/null || true

exit 0
POSTINST
chmod +x "$PKG_DIR/DEBIAN/postinst"

# postrm 脚本
cat > "$PKG_DIR/DEBIAN/postrm" << 'POSTRM'
#!/bin/bash
set -e

# 更新图标缓存
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi

# 更新桌面数据库
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi

# 完全卸载时清理
if [ "$1" = "purge" ]; then
    rm -rf /opt/label-load 2>/dev/null || true
fi

exit 0
POSTRM
chmod +x "$PKG_DIR/DEBIAN/postrm"

# ==============================================================================
# 设置权限
# ==============================================================================

log_info "设置权限..."

find "$PKG_DIR" -type d -exec chmod 755 {} \;
find "$PKG_DIR" -type f -exec chmod 644 {} \;

# 可执行文件
chmod 755 "$PKG_DIR/opt/$APP_NAME/label_load"
chmod 755 "$PKG_DIR/opt/$APP_NAME/label-load"
chmod 755 "$PKG_DIR/usr/bin/$APP_NAME"
chmod 755 "$PKG_DIR/DEBIAN/postinst"
chmod 755 "$PKG_DIR/DEBIAN/postrm"

# .so 文件
find "$PKG_DIR/opt/$APP_NAME/lib" -name "*.so*" -exec chmod 755 {} \;

# ==============================================================================
# 构建 DEB 包
# ==============================================================================

log_info "构建 DEB 包..."

DEB_FILE="$DEB_ROOT/${APP_NAME}_${VERSION}${PKG_SUFFIX}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$PKG_DIR" "$DEB_FILE"

# ==============================================================================
# 完成
# ==============================================================================

echo ""
echo "========================================"
log_success "打包完成！"
echo "========================================"
echo ""
echo "  文件: $(basename "$DEB_FILE")"
echo "  大小: $(du -h "$DEB_FILE" | cut -f1)"
echo "  类型: $BUILD_TYPE"
echo ""
echo "安装命令:"
echo "  sudo apt install $DEB_FILE"
echo ""

if [[ "$BUNDLE_GPU" == "true" ]]; then
    echo -e "${YELLOW}注意:${NC} GPU 推理需要用户自行安装 CUDA Toolkit"
    echo "  Ubuntu: sudo apt install nvidia-cuda-toolkit"
    echo ""
fi
