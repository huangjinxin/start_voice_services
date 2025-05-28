#!/bin/bash
# 语音识别服务启动脚本 (改进版)
# 文件名: start_voice_services.sh

# 配置基础路径
BASE_DIR="/Users/huang/Downloads/downlload/code-huangs/dockers/sherpa-onnx/sherpa-onnx"
LOGS_DIR="$BASE_DIR/logs"

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%H:%M:%S') $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $1"
}

# 设置环境函数
setup_environment() {
    print_info "设置环境..."
    
    # 切换到工作目录
    cd "$BASE_DIR" || {
        print_error "无法切换到目录: $BASE_DIR"
        exit 1
    }
    
    # 检查并激活conda环境
    if command -v conda &> /dev/null; then
        eval "$(conda shell.bash hook)"
        conda activate base 2>/dev/null || true
        print_info "已激活conda base环境"
    fi
    
    # 设置Python路径 - 直接使用当前目录，不依赖sherpa_onnx模块
    export PYTHONPATH="$BASE_DIR:$PYTHONPATH"
    
    print_info "当前Python: $(which python3)"
    print_info "当前目录: $(pwd)"
}

# 创建日志目录
create_log_dir() {
    mkdir -p "$LOGS_DIR"
    print_info "日志目录: $LOGS_DIR"
}

# 函数：检查端口是否被占用
check_port() {
    local port=$1
    lsof -ti:$port > /dev/null 2>&1
    return $?
}

# 函数：杀死占用端口的进程
kill_port_process() {
    local port=$1
    local pids=$(lsof -ti:$port 2>/dev/null)
    if [ -n "$pids" ]; then
        print_warning "杀死占用端口 $port 的进程: $pids"
        echo $pids | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
}

# 检查必要文件是否存在
check_required_files() {
    print_info "检查必要文件..."
    
    # 检查sherpa模型文件
    local model_file="./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/model.int8.onnx"
    local tokens_file="./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tokens.txt"
    local server_file="./python-api-examples/non_streaming_server.py"
    
    for file in "$model_file" "$tokens_file" "$server_file" "asr_openai_api.py" "voice_web.py"; do
        if [ ! -f "$file" ]; then
            print_error "缺少必要文件: $file"
            return 1
        fi
    done
    
    print_success "所有必要文件检查通过"
    return 0
}

# 函数：启动sherpa服务
start_sherpa() {
    print_info "启动 Sherpa 语音识别服务..."
    
    # 检查并清理端口
    if check_port 6006; then
        print_warning "端口 6006 被占用，清理中..."
        kill_port_process 6006
    fi
    
    # 使用完整路径启动sherpa服务，不依赖sherpa_onnx模块导入
    print_info "启动命令: python3 ./python-api-examples/non_streaming_server.py"
    
    nohup python3 ./python-api-examples/non_streaming_server.py \
        --sense-voice=./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/model.int8.onnx \
        --tokens=./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tokens.txt \
        --port=6006 \
        > "$LOGS_DIR/sherpa.log" 2>&1 &
    
    SHERPA_PID=$!
    print_success "Sherpa 服务已启动，PID: $SHERPA_PID"
    echo $SHERPA_PID > "$LOGS_DIR/sherpa.pid"
    
    # 等待服务启动
    print_info "等待 Sherpa 服务启动..."
    for i in {1..10}; do
        if check_port 6006; then
            print_success "Sherpa 服务启动成功 (端口 6006)"
            return 0
        fi
        sleep 1
    done
    
    print_error "Sherpa 服务启动失败，请检查日志"
    return 1
}

# 函数：启动API服务
start_api() {
    print_info "启动 ASR OpenAI API 服务..."
    
    # 检查并清理端口
    if check_port 8000; then
        print_warning "端口 8000 被占用，清理中..."
        kill_port_process 8000
    fi
    
    # 检查依赖
    if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
        print_error "缺少API服务依赖，请运行: pip3 install fastapi uvicorn python-multipart websockets"
        return 1
    fi
    
    # 启动API服务
    nohup python3 asr_openai_api.py > "$LOGS_DIR/api.log" 2>&1 &
    
    API_PID=$!
    print_success "API 服务已启动，PID: $API_PID"
    echo $API_PID > "$LOGS_DIR/api.pid"
    
    # 等待服务启动
    print_info "等待 API 服务启动..."
    for i in {1..10}; do
        if check_port 8000; then
            print_success "API 服务启动成功 (端口 8000)"
            return 0
        fi
        sleep 1
    done
    
    print_error "API 服务启动失败，请检查日志"
    return 1
}

# 函数：启动Web服务
start_web() {
    print_info "启动 Web 界面服务..."
    
    # 检查并清理端口
    if check_port 8888; then
        print_warning "端口 8888 被占用，清理中..."
        kill_port_process 8888
    fi
    
    # 启动Web服务
    nohup python3 voice_web.py > "$LOGS_DIR/web.log" 2>&1 &
    
    WEB_PID=$!
    print_success "Web 服务已启动，PID: $WEB_PID"
    echo $WEB_PID > "$LOGS_DIR/web.pid"
    
    # 等待服务启动
    print_info "等待 Web 服务启动..."
    for i in {1..10}; do
        if check_port 8888; then
            print_success "Web 服务启动成功 (端口 8888)"
            return 0
        fi
        sleep 1
    done
    
    print_error "Web 服务启动失败，请检查日志"
    return 1
}

# 函数：检查服务状态
check_services() {
    print_info "检查服务状态..."
    
    local all_ok=true
    
    # 检查sherpa服务
    if check_port 6006; then
        print_success "✅ Sherpa 服务运行正常 (端口 6006)"
    else
        print_error "❌ Sherpa 服务未运行"
        all_ok=false
    fi
    
    # 检查API服务
    if check_port 8000; then
        print_success "✅ API 服务运行正常 (端口 8000)"
        # 测试API健康检查
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            print_success "✅ API 健康检查通过"
        else
            print_warning "⚠️ API 服务响应异常"
        fi
    else
        print_error "❌ API 服务未运行"
        all_ok=false
    fi
    
    # 检查Web服务
    if check_port 8888; then
        print_success "✅ Web 服务运行正常 (端口 8888)"
    else
        print_error "❌ Web 服务未运行"
        all_ok=false
    fi
    
    if $all_ok; then
        echo ""
        print_success "🎉 所有服务运行正常！"
        print_info "🎤 访问地址: http://localhost:8888"
        print_info "🔌 API接口: http://localhost:8000/v1/audio/transcriptions"
        print_info "💊 健康检查: http://localhost:8000/health"
    fi
}

# 函数：停止所有服务
stop_services() {
    print_info "停止所有语音识别服务..."
    
    # 方法1: 通过PID文件停止
    for service in sherpa api web; do
        local pid_file="$LOGS_DIR/${service}.pid"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                print_info "停止 $service 服务 (PID: $pid)"
                kill "$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
            fi
            rm -f "$pid_file"
        fi
    done
    
    # 方法2: 通过进程名停止
    pkill -f "non_streaming_server.py" 2>/dev/null || true
    pkill -f "asr_openai_api" 2>/dev/null || true  
    pkill -f "voice_web.py" 2>/dev/null || true
    
    # 方法3: 通过端口强制停止
    for port in 6006 8000 8888; do
        kill_port_process $port
    done
    
    sleep 2
    print_success "所有服务已停止"
}

# 显示日志
show_logs() {
    local service=${1:-"all"}
    
    case $service in
        sherpa)
            print_info "=== Sherpa 日志 ==="
            tail -n 30 "$LOGS_DIR/sherpa.log" 2>/dev/null || echo "无日志文件"
            ;;
        api)
            print_info "=== API 日志 ==="
            tail -n 30 "$LOGS_DIR/api.log" 2>/dev/null || echo "无日志文件"
            ;;
        web)
            print_info "=== Web 日志 ==="
            tail -n 30 "$LOGS_DIR/web.log" 2>/dev/null || echo "无日志文件"
            ;;
        all|*)
            print_info "=== Sherpa 日志 ==="
            tail -n 20 "$LOGS_DIR/sherpa.log" 2>/dev/null || echo "无日志文件"
            echo ""
            print_info "=== API 日志 ==="
            tail -n 20 "$LOGS_DIR/api.log" 2>/dev/null || echo "无日志文件"
            echo ""
            print_info "=== Web 日志 ==="
            tail -n 20 "$LOGS_DIR/web.log" 2>/dev/null || echo "无日志文件"
            ;;
    esac
}

# 主程序
main() {
    case "$1" in
        start)
            print_info "🚀 开始启动语音识别服务套件..."
            
            # 设置环境
            setup_environment
            create_log_dir
            
            # 检查必要文件
            if ! check_required_files; then
                print_error "文件检查失败，无法启动服务"
                exit 1
            fi
            
            # 启动服务（按依赖顺序）
            if start_sherpa; then
                print_info "等待 Sherpa 完全启动..."
                sleep 3
                
                if start_api; then
                    print_info "等待 API 完全启动..."
                    sleep 2
                    
                    if start_web; then
                        print_info "等待 Web 完全启动..."
                        sleep 2
                        
                        # 最终检查
                        check_services
                        print_success "🎉 语音识别服务套件启动完成！"
                    else
                        print_error "Web服务启动失败"
                        exit 1
                    fi
                else
                    print_error "API服务启动失败"
                    exit 1
                fi
            else
                print_error "Sherpa服务启动失败"
                exit 1
            fi
            ;;
        
        stop)
            stop_services
            ;;
        
        restart)
            print_info "重启服务..."
            stop_services
            sleep 3
            $0 start
            ;;
        
        status)
            setup_environment
            check_services
            ;;
            
        logs)
            show_logs $2
            ;;
            
        test)
            setup_environment
            print_info "执行服务测试..."
            
            # 测试各个端口
            for port in 6006 8000 8888; do
                if check_port $port; then
                    print_success "端口 $port 可访问"
                else
                    print_error "端口 $port 不可访问"
                fi
            done
            
            # 测试API接口
            if curl -s http://localhost:8000/health > /dev/null 2>&1; then
                print_success "API 健康检查通过"
            else
                print_error "API 健康检查失败"
            fi
            ;;
        
        *)
            echo "语音识别服务管理工具"
            echo ""
            echo "用法: $0 {start|stop|restart|status|logs|test}"
            echo ""
            echo "命令说明:"
            echo "  start     - 启动所有服务"
            echo "  stop      - 停止所有服务"
            echo "  restart   - 重启所有服务"
            echo "  status    - 检查服务状态"
            echo "  logs      - 查看服务日志 (可选: sherpa|api|web)"
            echo "  test      - 测试服务连通性"
            echo ""
            echo "服务地址:"
            echo "  🎤 Web界面: http://localhost:8888"
            echo "  🔌 API接口: http://localhost:8000/v1/audio/transcriptions"
            echo "  💊 健康检查: http://localhost:8000/health"
            exit 1
            ;;
    esac
}

# 运行主程序
main "$@"