#!/bin/bash
# Sherpa-ONNX 安装脚本
# 文件名: install_sherpa_deps.sh

BASE_DIR="/Users/huang/Downloads/downlload/code-huangs/dockers/sherpa-onnx/sherpa-onnx"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检查并激活conda环境
setup_conda() {
    print_info "设置Conda环境..."
    
    if command -v conda &> /dev/null; then
        # 初始化conda
        eval "$(conda shell.bash hook)"
        
        # 激活base环境
        conda activate base
        print_success "已激活conda base环境"
        
        # 显示当前Python信息
        echo "当前Python版本: $(python3 --version)"
        echo "当前Python路径: $(which python3)"
    else
        print_warning "未找到conda，使用系统Python"
    fi
}

# 安装Python依赖
install_python_deps() {
    print_info "安装Python依赖包..."
    
    # 基础依赖
    print_info "安装基础依赖..."
    pip3 install --upgrade pip
    pip3 install fastapi uvicorn python-multipart
    pip3 install numpy websockets
    
    # 尝试安装sherpa-onnx
    print_info "安装sherpa-onnx..."
    
    # 方法1: 通过pip安装
    if pip3 install sherpa-onnx; then
        print_success "通过pip成功安装sherpa-onnx"
        return 0
    fi
    
    print_warning "pip安装失败，尝试其他方法..."
    
    # 方法2: 检查是否已经编译好的版本
    cd "$BASE_DIR"
    
    if [ -f "build/lib/sherpa_onnx.py" ]; then
        print_info "找到本地编译版本，设置PYTHONPATH..."
        export PYTHONPATH="$BASE_DIR/build/lib:$PYTHONPATH"
        echo "export PYTHONPATH=\"$BASE_DIR/build/lib:\$PYTHONPATH\"" >> ~/.bashrc
        print_success "已设置本地sherpa-onnx路径"
        return 0
    fi
    
    # 方法3: 下载预编译wheel
    print_info "尝试下载预编译包..."
    
    # 获取系统信息
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PLATFORM=$(uname -m)
    
    print_info "Python版本: $PYTHON_VERSION, 平台: $PLATFORM"
    
    # 尝试从不同源下载
    URLS=(
        "https://pypi.org/simple/sherpa-onnx/"
        "https://github.com/k2-fsa/sherpa-onnx/releases/latest"
    )
    
    for url in "${URLS[@]}"; do
        print_info "尝试从 $url 下载..."
        if pip3 install sherpa-onnx --index-url $url --trusted-host pypi.org; then
            print_success "成功下载并安装sherpa-onnx"
            return 0
        fi
    done
    
    print_error "所有安装方法都失败了"
    return 1
}

# 验证安装
verify_installation() {
    print_info "验证安装..."
    
    # 测试导入
    if python3 -c "import sherpa_onnx; print('sherpa_onnx version:', sherpa_onnx.__version__ if hasattr(sherpa_onnx, '__version__') else 'unknown')" 2>/dev/null; then
        print_success "sherpa_onnx 导入成功"
    else
        print_error "sherpa_onnx 导入失败"
        
        # 提供手动解决方案
        print_info "手动解决方案:"
        echo "1. 检查是否有预编译的sherpa-onnx文件:"
        echo "   find $BASE_DIR -name '*sherpa*' -type f"
        echo ""
        echo "2. 或者尝试从源码编译:"
        echo "   cd $BASE_DIR"
        echo "   mkdir -p build && cd build"
        echo "   cmake .."
        echo "   make -j4"
        echo ""
        echo "3. 或者下载预编译版本:"
        echo "   https://github.com/k2-fsa/sherpa-onnx/releases"
        
        return 1
    fi
    
    # 测试其他依赖
    DEPS=("fastapi" "uvicorn" "websockets" "numpy")
    for dep in "${DEPS[@]}"; do
        if python3 -c "import $dep" 2>/dev/null; then
            print_success "$dep 可用"
        else
            print_error "$dep 不可用"
        fi
    done
}

# 创建环境配置文件
create_env_config() {
    print_info "创建环境配置文件..."
    
    ENV_FILE="$BASE_DIR/env_setup.sh"
    
    cat > "$ENV_FILE" << 'EOF'
#!/bin/bash
# 环境配置文件

# 设置基础路径
export BASE_DIR="/Users/huang/Downloads/downlload/code-huangs/dockers/sherpa-onnx/sherpa-onnx"

# 设置PYTHONPATH
export PYTHONPATH="$BASE_DIR:$BASE_DIR/build/lib:$PYTHONPATH"

# 激活conda环境（如果存在）
if command -v conda &> /dev/null; then
    eval "$(conda shell.bash hook)"
    conda activate base 2>/dev/null || true
fi

# 设置PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "环境已配置 - Python: $(which python3)"
EOF
    
    chmod +x "$ENV_FILE"
    print_success "环境配置文件已创建: $ENV_FILE"
}

# 测试服务启动
test_services() {
    print_info "测试服务启动..."
    
    cd "$BASE_DIR"
    
    # 加载环境
    source "$BASE_DIR/env_setup.sh"
    
    # 测试sherpa服务
    print_info "测试Sherpa服务..."
    timeout 10 python3 ./python-api-examples/non_streaming_server.py \
        --sense-voice=./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/model.int8.onnx \
        --tokens=./sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/tokens.txt \
        --port=6007 &
    
    SHERPA_PID=$!
    sleep 3
    
    if kill -0 $SHERPA_PID 2>/dev/null; then
        print_success "Sherpa服务启动成功"
        kill $SHERPA_PID 2>/dev/null
    else
        print_error "Sherpa服务启动失败"
    fi
}

# 主函数
main() {
    print_info "开始安装Sherpa-ONNX依赖..."
    
    # 检查基础目录
    if [ ! -d "$BASE_DIR" ]; then
        print_error "基础目录不存在: $BASE_DIR"
        exit 1
    fi
    
    cd "$BASE_DIR"
    
    # 设置conda环境
    setup_conda
    
    # 安装Python依赖
    if ! install_python_deps; then
        print_error "依赖安装失败"
        exit 1
    fi
    
    # 验证安装
    if ! verify_installation; then
        print_warning "验证失败，但继续进行..."
    fi
    
    # 创建环境配置
    create_env_config
    
    # 测试服务
    test_services
    
    print_success "安装完成！"
    print_info "请运行以下命令更新启动脚本:"
    echo "  source $BASE_DIR/env_setup.sh"
    echo "  ./start_voice_services.sh start"
}

# 运行主函数
main "$@"
