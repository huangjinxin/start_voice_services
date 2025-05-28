#!/bin/bash
# 语音识别服务安装和管理脚本
# 文件名: setup_voice_recognition.sh

# 配置路径
BASE_DIR="/Users/huang/Downloads/downlload/code-huangs/dockers/sherpa-onnx/sherpa-onnx"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="com.huang.voice-recognition.plist"
STARTUP_SCRIPT="start_voice_services.sh"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印彩色输出
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 函数：检查依赖
check_dependencies() {
    print_info "检查系统依赖..."
    
    # 检查Python3
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 未安装"
        exit 1
    fi
    
    # 检查ffmpeg
    if ! command -v ffmpeg &> /dev/null; then
        print_warning "ffmpeg 未安装，建议安装: brew install ffmpeg"
    fi
    
    # 检查uvicorn
    if ! python3 -c "import uvicorn" &> /dev/null; then
        print_error "uvicorn 未安装，请运行: pip3 install uvicorn"
        exit 1
    fi
    
    # 检查fastapi
    if ! python3 -c "import fastapi" &> /dev/null; then
        print_error "fastapi 未安装，请运行: pip3 install fastapi"
        exit 1
    fi
    
    print_success "依赖检查完成"
}

# 函数：安装服务
install_service() {
    print_info "安装语音识别服务..."
    
    # 检查基础目录
    if [ ! -d "$BASE_DIR" ]; then
        print_error "基础目录不存在: $BASE_DIR"
        exit 1
    fi
    
    cd "$BASE_DIR"
    
    # 创建启动脚本
    print_info "创建启动脚本..."
    # 这里需要您手动复制第一个artifact的内容到 start_voice_services.sh
    
    # 设置执行权限
    chmod +x "$STARTUP_SCRIPT"
    
    # 创建LaunchAgents目录
    mkdir -p "$LAUNCHD_DIR"
    
    # 创建plist文件
    print_info "创建系统服务配置..."
    # 这里需要您手动复制第二个artifact的内容到对应文件
    
    # 加载服务
    launchctl load "$LAUNCHD_DIR/$PLIST_FILE"
    
    print_success "服务安装完成！"
}

# 函数：卸载服务
uninstall_service() {
    print_info "卸载语音识别服务..."
    
    # 停止并卸载服务
    launchctl unload "$LAUNCHD_DIR/$PLIST_FILE" 2>/dev/null || true
    
    # 删除plist文件
    rm -f "$LAUNCHD_DIR/$PLIST_FILE"
    
    # 停止运行中的服务
    "$BASE_DIR/$STARTUP_SCRIPT" stop 2>/dev/null || true
    
    print_success "服务卸载完成"
}

# 函数：启动服务
start_service() {
    print_info "启动语音识别服务..."
    launchctl start com.huang.voice-recognition
    sleep 3
    "$BASE_DIR/$STARTUP_SCRIPT" status
}

# 函数：停止服务
stop_service() {
    print_info "停止语音识别服务..."
    launchctl stop com.huang.voice-recognition
    "$BASE_DIR/$STARTUP_SCRIPT" stop
}

# 函数：查看服务状态
show_status() {
    print_info "语音识别服务状态:"
    echo ""
    
    # 检查launchd服务状态
    if launchctl list | grep -q "com.huang.voice-recognition"; then
        print_success "系统服务: 已注册"
    else
        print_warning "系统服务: 未注册"
    fi
    
    # 检查各个组件状态
    "$BASE_DIR/$STARTUP_SCRIPT" status
    
    echo ""
    print_info "服务地址:"
    echo "  🎤 Web界面: http://localhost:8888"
    echo "  🔌 API接口: http://localhost:8000"
    echo "  🧠 Sherpa: ws://localhost:6006"
}

# 函数：查看日志
show_logs() {
    print_info "查看服务日志..."
    echo ""
    
    echo "=== LaunchD 启动日志 ==="
    tail -n 10 "$BASE_DIR/logs/launchd.out.log" 2>/dev/null || echo "无启动日志"
    echo ""
    
    echo "=== LaunchD 错误日志 ==="
    tail -n 10 "$BASE_DIR/logs/launchd.err.log" 2>/dev/null || echo "无错误日志"
    echo ""
    
    "$BASE_DIR/$STARTUP_SCRIPT" logs
}

# 函数：重新安装服务
reinstall_service() {
    print_info "重新安装语音识别服务..."
    uninstall_service
    sleep 2
    install_service
}

# 函数：快速测试
quick_test() {
    print_info "执行快速测试..."
    
    # 测试端口连通性
    if lsof -ti:6006 > /dev/null 2>&1; then
        print_success "Sherpa服务 (6006) 运行正常"
    else
        print_error "Sherpa服务 (6006) 未运行"
    fi
    
    if lsof -ti:8000 > /dev/null 2>&1; then
        print_success "API服务 (8000) 运行正常"
    else
        print_error "API服务 (8000) 未运行"
    fi
    
    if lsof -ti:8888 > /dev/null 2>&1; then
        print_success "Web服务 (8888) 运行正常"
    else
        print_error "Web服务 (8888) 未运行"
    fi
    
    # 测试API接口
    if curl -s http://localhost:8000/health > /dev/null; then
        print_success "API健康检查通过"
    else
        print_warning "API健康检查失败"
    fi
}

# 显示帮助信息
show_help() {
    echo "语音识别服务管理工具"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  install     - 安装并启用开机自启动"
    echo "  uninstall   - 卸载服务"
    echo "  reinstall   - 重新安装服务"
    echo "  start       - 启动服务"
    echo "  stop        - 停止服务"
    echo "  status      - 查看服务状态"
    echo "  logs        - 查看服务日志"
    echo "  test        - 快速测试服务"
    echo "  check       - 检查系统依赖"
    echo "  help        - 显示此帮助信息"
    echo ""
    echo "安装后的服务地址:"
    echo "  🎤 Web界面: http://localhost:8888"
    echo "  🔌 API接口: http://localhost:8000/v1/audio/transcriptions"
    echo "  💊 健康检查: http://localhost:8000/health"
}

# 主程序
case "$1" in
    install)
        check_dependencies
        install_service
        start_service
        ;;
    uninstall)
        uninstall_service
        ;;
    reinstall)
        reinstall_service
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    test)
        quick_test
        ;;
    check)
        check_dependencies
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        if [ -z "$1" ]; then
            show_help
        else
            print_error "未知命令: $1"
            echo ""
            show_help
        fi
        exit 1
        ;;
esac

exit 0
