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
