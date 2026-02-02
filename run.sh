#!/bin/bash
# ==============================================================================
# LabelLoad - 统一构建运行工具
# ==============================================================================
# 用法: ./run.sh <命令> [选项]
#
# 开发命令:
#   clean         清理构建产物
#   debug         构建调试版本
#   run           运行调试版本
#   release       构建 release 版本
#
# 打包命令:
#   deb           打包 DEB (需先 release)
#     --gpu         GPU 版本
#     --cpu         CPU 版本 (默认)
#     --version X   指定版本号
#
# 测试命令:
#   test          运行所有测试
#     --unit        仅单元测试
#     --int         仅集成测试
#     --native      仅原生 C++ 测试
#     --coverage    生成覆盖率报告
#
# 代码质量:
#   analyze       静态分析
#   format        格式检查
#   version       显示版本信息
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 从 pubspec.yaml 读取版本号
read_pubspec_version() {
    local pubspec="$SCRIPT_DIR/pubspec.yaml"
    local version=""

    if [[ -f "$pubspec" ]]; then
        version=$(awk -F': *' '/^version:/ {print $2; exit}' "$pubspec")
    fi

    if [[ -z "$version" ]]; then
        version="0.0.0"
    fi

    echo "$version"
}

# 版本信息
readonly APP_VERSION="$(read_pubspec_version)"
readonly APP_VERSION_BASE="${APP_VERSION%%+*}"
readonly APP_NAME="LabelLoad"
readonly SCRIPT_VERSION="2.2.0"

# GTK 环境变量（抑制无关警告）
export GTK_IM_MODULE="${GTK_IM_MODULE:-gtk-im-context-simple}"
export NO_AT_BRIDGE=1
export GTK_A11Y=none

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

# 错误处理
trap 'log_error "命令失败于第 $LINENO 行"' ERR

# ==============================================================================
# 环境检查
# ==============================================================================

check_flutter() {
    if ! command -v flutter &> /dev/null; then
        log_error "未找到 Flutter SDK"
        echo "安装指南: https://docs.flutter.dev/get-started/install/linux"
        exit 1
    fi
}

check_release_build() {
    local bundle="$SCRIPT_DIR/build/linux/x64/release/bundle"
    if [[ ! -f "$bundle/label_load" ]]; then
        log_error "未找到 release 构建产物"
        echo ""
        echo "请先运行: ./run.sh release"
        exit 1
    fi
}

# ==============================================================================
# 帮助和版本
# ==============================================================================

show_help() {
    echo -e "${BOLD}${BLUE}$APP_NAME${NC} - 统一构建运行工具 (v$SCRIPT_VERSION)"
    echo ""
    echo -e "${YELLOW}用法:${NC} $0 <命令> [选项]"
    echo ""
    echo -e "${YELLOW}开发命令:${NC}"
    echo "  clean         清理构建产物"
    echo "  debug         构建调试版本"
    echo "  run           运行调试版本"
    echo "  release       构建 release 版本"
    echo ""
    echo -e "${YELLOW}打包命令:${NC}"
    echo "  deb           打包 DEB (需先 release)"
    echo "    --gpu         GPU 版本 (~120MB)"
    echo "    --cpu         CPU 版本 (默认，~18MB)"
    echo "    --version X   指定版本号 (默认 $APP_VERSION_BASE)"
    echo ""
    echo -e "${YELLOW}测试命令:${NC}"
    echo "  test          运行所有测试"
    echo "    --unit        仅单元测试"
    echo "    --int         仅集成测试"
    echo "    --native      仅原生 C++ 测试"
    echo "    --coverage    生成覆盖率报告"
    echo ""
    echo -e "${YELLOW}代码质量:${NC}"
    echo "  analyze       静态分析"
    echo "  format        格式检查"
    echo "  version       显示版本信息"
    echo ""
    echo -e "${YELLOW}工作流示例:${NC}"
    echo "  ./run.sh debug && ./run.sh run   # 开发调试"
    echo "  ./run.sh release && ./run.sh deb # 构建+打包"
}

show_version() {
    echo -e "${BOLD}$APP_NAME${NC}"
    echo "  应用版本: $APP_VERSION"
    echo "  脚本版本: $SCRIPT_VERSION"
    echo ""
    
    if command -v flutter &> /dev/null; then
        local flutter_ver=$(flutter --version | head -1 | awk '{print $2}')
        echo "  Flutter:  $flutter_ver"
    else
        echo "  Flutter:  未安装"
    fi
}

# ==============================================================================
# 开发功能
# ==============================================================================

do_clean() {
    log_info "清理构建产物..."
    
    log_step "清理 Flutter 构建缓存"
    rm -rf build .dart_tool coverage
    flutter clean 2>/dev/null || true
    
    log_step "清理 onnx_inference 构建缓存"
    rm -rf onnx_inference/build onnx_inference/.dart_tool
    (cd onnx_inference && flutter clean 2>/dev/null) || true
    
    log_success "清理完成"
}

do_build_debug() {
    check_flutter
    log_info "构建调试版本..."
    
    log_step "获取依赖"
    flutter pub get
    
    log_step "构建 Linux 调试版本"
    flutter build linux --debug
    
    log_success "调试版本构建完成"
    echo "    路径: build/linux/x64/debug/bundle/label_load"
}

do_build_release() {
    check_flutter
    log_info "构建 release 版本..."
    
    log_step "获取依赖"
    flutter pub get
    
    log_step "构建 Linux release 版本"
    flutter build linux --release
    
    log_success "Release 版本构建完成"
    echo "    路径: build/linux/x64/release/bundle/label_load"
    echo ""
    echo "下一步: ./run.sh deb [--cpu|--gpu]"
}

do_run() {
    local bundle="$SCRIPT_DIR/build/linux/x64/debug/bundle"
    
    if [[ ! -f "$bundle/label_load" ]]; then
        log_warn "调试版本未构建，正在构建..."
        do_build_debug
    fi
    
    log_info "运行调试版本..."
    cd "$bundle"
    ./label_load
}

# ==============================================================================
# 打包功能
# ==============================================================================

do_deb() {
    check_release_build
    
    local deb_flags=""
    local version_flag=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --gpu)
                # 默认行为，不需要特殊标志
                ;;
            --cpu)
                deb_flags="--cpu-only"
                ;;
            --version)
                shift
                if [[ -n "${1:-}" ]]; then
                    version_flag="--version $1"
                else
                    log_error "--version 需要指定版本号"
                    exit 1
                fi
                ;;
            *)
                log_warn "未知选项: $1"
                ;;
        esac
        shift
    done
    
    log_info "打包 DEB..."
    "$SCRIPT_DIR/packaging/build_deb.sh" $deb_flags $version_flag
}

# ==============================================================================
# 测试功能
# ==============================================================================

do_test_unit() {
    check_flutter
    log_info "运行单元测试..."
    
    log_step "获取依赖"
    flutter pub get
    
    log_step "运行主项目单元测试"
    flutter test --reporter expanded
    
    log_step "运行 onnx_inference 单元测试"
    (cd "$SCRIPT_DIR/onnx_inference" && flutter pub get && flutter test --reporter expanded)
    
    log_success "单元测试完成"
}

do_test_integration() {
    check_flutter
    log_info "运行集成测试..."
    
    flutter pub get
    
    mapfile -t tests < <(find "$SCRIPT_DIR/integration_test" -name "*_test.dart" -print | sort)
    if [[ ${#tests[@]} -eq 0 ]]; then
        log_warn "未找到集成测试文件"
        return 0
    fi
    
    local passed=0
    local failed=0
    
    for test_file in "${tests[@]}"; do
        local test_name=$(basename "$test_file")
        log_step "运行: $test_name"
        if flutter test "$test_file" -d linux --reporter expanded; then
            ((passed++)) || true
        else
            ((failed++)) || true
            log_warn "测试失败: $test_name"
        fi
    done
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        log_success "集成测试完成: $passed 个通过"
    else
        log_warn "集成测试完成: $passed 个通过, $failed 个失败"
    fi
}

do_test_native() {
    log_info "运行原生 (C++) 测试..."
    
    if ! command -v cmake &> /dev/null; then
        log_error "未找到 cmake，无法运行原生测试"
        echo "安装: sudo apt install cmake"
        exit 1
    fi
    
    local build_dir="$SCRIPT_DIR/onnx_inference/build"
    
    log_step "配置 CMake"
    cmake -S "$SCRIPT_DIR/onnx_inference/src" -B "$build_dir" -DONNX_INFERENCE_BUILD_TESTS=ON
    
    log_step "编译测试"
    cmake --build "$build_dir" --target onnx_inference_utils_test onnx_inference_stub_test
    
    log_step "运行测试"
    ctest --test-dir "$build_dir" --output-on-failure
    
    log_success "原生测试完成"
}

do_test_coverage() {
    check_flutter
    log_info "运行测试并生成覆盖率报告..."
    
    flutter pub get
    
    log_step "运行主项目覆盖率测试"
    flutter test --coverage --reporter expanded
    
    log_step "运行 onnx_inference 覆盖率测试"
    (cd "$SCRIPT_DIR/onnx_inference" && flutter pub get && flutter test --coverage --reporter expanded)
    
    if command -v genhtml &> /dev/null; then
        log_step "生成 HTML 覆盖率报告"
        genhtml coverage/lcov.info -o coverage/html --quiet
        log_success "HTML 报告: coverage/html/index.html"
    else
        log_warn "提示: 安装 lcov 可生成 HTML 报告"
        echo "    sudo apt install lcov"
    fi
}

do_test() {
    local run_unit=true
    local run_int=true
    local run_native=false
    local run_coverage=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unit)
                run_unit=true
                run_int=false
                ;;
            --int)
                run_unit=false
                run_int=true
                ;;
            --native)
                run_unit=false
                run_int=false
                run_native=true
                ;;
            --coverage)
                run_coverage=true
                ;;
            *)
                log_warn "未知测试选项: $1"
                ;;
        esac
        shift
    done
    
    if $run_coverage; then
        do_test_coverage
    elif $run_native; then
        do_test_native
    else
        if $run_unit; then
            do_test_unit
        fi
        if $run_int; then
            do_test_integration
        fi
    fi
}

# ==============================================================================
# 代码质量
# ==============================================================================

do_analyze() {
    check_flutter
    log_info "运行静态分析..."
    
    flutter pub get
    
    log_step "分析主项目"
    flutter analyze
    
    log_step "分析 onnx_inference"
    (cd "$SCRIPT_DIR/onnx_inference" && flutter pub get && flutter analyze)
    
    log_success "静态分析完成"
}

do_format() {
    check_flutter
    log_info "运行格式检查..."
    
    flutter pub get
    
    log_step "检查 lib/ 和 test/"
    dart format --set-exit-if-changed lib test
    
    log_step "检查 integration_test/"
    dart format --set-exit-if-changed integration_test
    
    log_success "格式检查完成"
}

# ==============================================================================
# 主入口
# ==============================================================================

main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true
    
    case "$cmd" in
        # 开发命令
        clean)    do_clean ;;
        debug)    do_build_debug ;;
        release)  do_build_release ;;
        run)      do_run ;;
        
        # 打包命令
        deb)      do_deb "$@" ;;
        
        # 测试命令
        test)     do_test "$@" ;;
        
        # 代码质量
        analyze)  do_analyze ;;
        format)   do_format ;;
        version)  show_version ;;
        
        # 帮助
        help|-h|--help)
            show_help
            ;;
        *)
            log_error "未知命令: $cmd"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
