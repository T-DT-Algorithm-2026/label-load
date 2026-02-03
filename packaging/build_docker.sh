#!/bin/bash
# ==============================================================================
# LabelLoad Docker 构建脚本
# ==============================================================================
# 完全在 Docker 内完成构建，不依赖宿主机环境
#
# 用法: ./packaging/build_docker.sh [选项]
#   --gpu            构建 GPU 版本 (需用户自装 CUDA)
#   --cpu            构建 CPU 版本 (默认)
#   --rebuild        强制重建 Docker 镜像
#   --version X      指定版本号 (默认读取 build_deb.sh)
#   --ort-version X  指定 ONNX Runtime 版本
#   --no-cache       Docker 构建不使用缓存
#
# 输出: build/release/label-load_版本_amd64.deb
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# ==============================================================================
# 颜色和日志
# ==============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[DONE]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step()    { echo -e "${CYAN}  →${NC} $1"; }

# ==============================================================================
# 配置
# ==============================================================================

# 默认配置
WITH_GPU=false
REBUILD=false
NO_CACHE=false
VERSION=""
ORT_VERSION="1.23.0"

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --gpu)
            WITH_GPU=true
            ;;
        --cpu)
            WITH_GPU=false
            ;;
        --rebuild)
            REBUILD=true
            ;;
        --no-cache)
            NO_CACHE=true
            ;;
        --version)
            shift
            if [[ -n "${1:-}" ]]; then
                VERSION="$1"
            else
                log_error "--version 需要指定版本号"
                exit 1
            fi
            ;;
        --ort-version)
            shift
            if [[ -n "${1:-}" ]]; then
                ORT_VERSION="$1"
            else
                log_error "--ort-version 需要指定版本号"
                exit 1
            fi
            ;;
        *)
            log_warn "未知参数: $1"
            ;;
    esac
    shift
done

# 镜像名称
if $WITH_GPU; then
    IMAGE_NAME="label-load-builder:gpu-${ORT_VERSION}"
    BUILD_TYPE="GPU"
    DEB_FLAG=""
else
    IMAGE_NAME="label-load-builder:cpu-${ORT_VERSION}"
    BUILD_TYPE="CPU"
    DEB_FLAG="--cpu-only"
fi

# 版本参数
VERSION_FLAG=""
if [[ -n "$VERSION" ]]; then
    VERSION_FLAG="--version $VERSION"
fi

CONTAINER_NAME="label-load-build-$$"

# ==============================================================================
# 环境检查
# ==============================================================================

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "未安装 Docker"
        echo ""
        echo "安装指南:"
        echo "  Ubuntu: https://docs.docker.com/engine/install/ubuntu/"
        echo "  其他: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker 守护进程未运行或权限不足"
        echo ""
        echo "尝试以下方法:"
        echo "  1. 启动 Docker: sudo systemctl start docker"
        echo "  2. 加入 docker 组: sudo usermod -aG docker \$USER && newgrp docker"
        exit 1
    fi
}

# ==============================================================================
# Docker 镜像管理
# ==============================================================================

need_rebuild() {
    # 强制重建
    if $REBUILD; then
        return 0
    fi
    
    # 镜像不存在
    if [[ "$(docker images -q "$IMAGE_NAME" 2>/dev/null)" == "" ]]; then
        return 0
    fi
    
    # 检查 Dockerfile 是否比镜像新
    local dockerfile="$SCRIPT_DIR/Dockerfile.build"
    if [[ -f "$dockerfile" ]]; then
        local image_date=$(docker inspect -f '{{.Created}}' "$IMAGE_NAME" 2>/dev/null | cut -d'T' -f1)
        local file_date=$(date -r "$dockerfile" +%Y-%m-%d)
        
        if [[ "$file_date" > "$image_date" ]]; then
            log_info "Dockerfile 已更新，需要重建镜像"
            return 0
        fi
    fi
    
    return 1
}

build_docker_image() {
    log_info "构建 Docker 镜像: $IMAGE_NAME"
    
    local cache_flag=""
    if $NO_CACHE; then
        cache_flag="--no-cache"
    fi
    
    docker build \
        $cache_flag \
        --build-arg WITH_GPU=$WITH_GPU \
        --build-arg ORT_VERSION=$ORT_VERSION \
        -t "$IMAGE_NAME" \
        -f "$SCRIPT_DIR/Dockerfile.build" \
        "$SCRIPT_DIR"
    
    log_success "镜像构建完成"
}

# ==============================================================================
# 构建流程
# ==============================================================================

run_build() {
    log_info "在容器中构建应用..."
    
    # 构建命令
    docker run --rm \
        --name "$CONTAINER_NAME" \
        -v "$PROJECT_DIR:/app" \
        -w /app \
        "$IMAGE_NAME" -c "
        set -e
        
        echo '[INFO] 清理旧构建...'
        rm -rf build/linux build/deb
        
        echo '[INFO] 获取依赖...'
        flutter pub get
        
        echo '[INFO] 构建 release 版本...'
        flutter build linux --release
        
        echo '[INFO] 打包 DEB...'
        ./packaging/build_deb.sh $DEB_FLAG $VERSION_FLAG
    "
}

fix_permissions() {
    log_step "修复文件权限..."
    
    local current_user=$(id -u):$(id -g)
    # 修复所有 Docker 创建的文件权限
    docker run --rm -v "$PROJECT_DIR:/app" ubuntu:22.04 \
        bash -c "chown -R $current_user /app/build /app/.dart_tool /app/.flutter-plugins /app/.flutter-plugins-dependencies /app/pubspec.lock 2>/dev/null || true"
}

move_artifacts() {
    local output_dir="$PROJECT_DIR/build/release"
    mkdir -p "$output_dir"
    
    if ls "$PROJECT_DIR/build/deb/"*.deb 1> /dev/null 2>&1; then
        mv "$PROJECT_DIR/build/deb/"*.deb "$output_dir/"
    fi
}

show_result() {
    echo ""
    echo "========================================"
    log_success "构建完成！"
    echo "========================================"
    
    local deb_file=$(ls -t "$PROJECT_DIR/build/release/"*.deb 2>/dev/null | head -1)
    
    if [[ -f "$deb_file" ]]; then
        local size=$(du -h "$deb_file" | cut -f1)
        local filename=$(basename "$deb_file")
        
        echo ""
        echo "  文件: $filename"
        echo "  大小: $size"
        echo "  类型: $BUILD_TYPE"
        echo "  路径: $deb_file"
        echo ""
        echo "安装命令:"
        echo "  sudo apt install $deb_file"
        echo ""
        
        if $WITH_GPU; then
            echo -e "${YELLOW}注意:${NC} GPU 版本需要用户自行安装 CUDA Toolkit"
            echo "  Ubuntu: sudo apt install nvidia-cuda-toolkit"
            echo ""
        fi
    else
        log_warn "未找到生成的 DEB 包"
    fi
}

# ==============================================================================
# 主流程
# ==============================================================================

main() {
    echo ""
    echo "========================================"
    echo -e "  ${BOLD}${BLUE}LabelLoad Docker 构建${NC}"
    echo "========================================"
    echo "  版本类型: $BUILD_TYPE"
    echo "  ORT 版本: $ORT_VERSION"
    echo "  基于 Ubuntu 22.04"
    echo "========================================"
    echo ""
    
    check_docker
    
    # 检查是否需要构建镜像
    if need_rebuild; then
        build_docker_image
    else
        log_info "使用已有镜像: $IMAGE_NAME"
    fi
    
    # 运行构建
    run_build
    
    # 修复权限
    fix_permissions
    
    # 移动产物
    move_artifacts
    
    # 显示结果
    show_result
}

main
