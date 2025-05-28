import wave
import numpy as np
import tempfile
import asyncio
import websockets
import logging
import os
import subprocess
import shutil
from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import traceback
from typing import Optional

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 允许所有来源
    allow_credentials=True,
    allow_methods=["*"],  # 允许所有HTTP方法
    allow_headers=["*"],  # 允许所有头部
)

SHERPA_WS_HOST = "127.0.0.1"
SHERPA_WS_PORT = 6006

# 检查 ffmpeg 是否可用
def check_ffmpeg():
    """检查系统是否安装了 ffmpeg"""
    return shutil.which("ffmpeg") is not None

# 使用 ffmpeg 转换音频格式为 WAV
def convert_to_wav(input_path: str, output_path: str):
    """使用 ffmpeg 将音频文件转换为 WAV 格式"""
    try:
        cmd = [
            "ffmpeg", "-i", input_path,
            "-ar", "16000",  # 采样率设为 16kHz
            "-ac", "1",      # 单声道
            "-sample_fmt", "s16",  # 16-bit 采样
            "-y",            # 覆盖输出文件
            output_path
        ]
        
        result = subprocess.run(
            cmd, 
            capture_output=True, 
            text=True, 
            check=True
        )
        
        logger.info(f"音频转换成功: {input_path} -> {output_path}")
        return True
        
    except subprocess.CalledProcessError as e:
        logger.error(f"ffmpeg 转换失败: {e}")
        logger.error(f"ffmpeg stderr: {e.stderr}")
        return False
    except Exception as e:
        logger.error(f"音频转换异常: {e}")
        return False

# 读取 wav 文件，返回 float32 数组和采样率
def read_wave(wav_path):
    try:
        with wave.open(wav_path, "rb") as wf:
            # 记录音频文件信息
            channels = wf.getnchannels()
            sample_width = wf.getsampwidth()
            sample_rate = wf.getframerate()
            n_frames = wf.getnframes()
            
            logger.info(f"音频信息: 通道数={channels}, 采样宽度={sample_width}, 采样率={sample_rate}, 帧数={n_frames}")
            
            frames = wf.readframes(n_frames)
            
            # 处理16-bit音频数据
            if sample_width == 2:  # 16-bit
                samples = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
            else:
                raise ValueError(f"不支持的采样宽度: {sample_width}")
            
            # 如果是多通道，取平均值转为单通道
            if channels > 1:
                samples = samples.reshape(-1, channels)
                samples = np.mean(samples, axis=1)
            
            return samples, sample_rate
            
    except Exception as e:
        logger.error(f"读取音频文件失败: {e}")
        raise

# 按照 sherpa 的协议发送 wav 数据并获取返回
async def send_to_sherpa(samples: np.ndarray, sample_rate: int) -> str:
    uri = f"ws://{SHERPA_WS_HOST}:{SHERPA_WS_PORT}"
    try:
        logger.info(f"连接到 Sherpa WebSocket: {uri}")
        async with websockets.connect(uri) as ws:
            # 构造数据包：采样率(4字节) + 样本字节大小(4字节) + 样本字节流
            buf = sample_rate.to_bytes(4, "little")
            buf += (samples.size * 4).to_bytes(4, "little")
            buf += samples.tobytes()
            
            logger.info(f"发送数据包大小: {len(buf)} 字节")
            
            # 分块发送
            payload_len = 10240
            while len(buf) > payload_len:
                await ws.send(buf[:payload_len])
                buf = buf[payload_len:]
            if buf:
                await ws.send(buf)
            
            # 等待识别结果
            result = await ws.recv()
            await ws.send("Done")  # 通知服务器传输结束
            
            logger.info(f"收到识别结果: {result}")
            return result
            
    except Exception as e:
        logger.error(f"Sherpa WebSocket 连接失败: {e}")
        raise

# 处理 OPTIONS 预检请求
@app.options("/v1/audio/transcriptions")
async def transcriptions_options():
    return JSONResponse(
        content={},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "*",
        }
    )

# OpenAI API 兼容接口
@app.post("/v1/audio/transcriptions")
async def transcribe_audio(
    request: Request,
    file: UploadFile = File(...),
    model: Optional[str] = Form(None),
    language: Optional[str] = Form(None),
    prompt: Optional[str] = Form(None),
    response_format: Optional[str] = Form("json"),
    temperature: Optional[float] = Form(None)
):
    temp_path = None
    wav_path = None
    
    try:
        # 记录请求信息
        logger.info(f"收到转录请求:")
        logger.info(f"  文件名: {file.filename}")
        logger.info(f"  内容类型: {file.content_type}")
        logger.info(f"  模型: {model}")
        logger.info(f"  语言: {language}")
        logger.info(f"  响应格式: {response_format}")
        
        # 检查文件类型
        if not file.filename:
            raise HTTPException(status_code=400, detail="未提供文件名")
        
        # 检查 ffmpeg 是否可用
        if not check_ffmpeg():
            raise HTTPException(status_code=500, detail="系统未安装 ffmpeg，无法处理音频格式转换")
        
        # 读取上传的文件
        content = await file.read()
        logger.info(f"文件大小: {len(content)} 字节")
        
        if len(content) == 0:
            raise HTTPException(status_code=400, detail="上传的文件为空")
        
        # 获取文件扩展名
        file_suffix = os.path.splitext(file.filename)[1].lower()
        if not file_suffix:
            file_suffix = ".webm"  # 默认为 webm（网页常用格式）
            
        # 创建临时文件保存原始音频
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_suffix) as tmp:
            tmp.write(content)
            temp_path = tmp.name
        
        logger.info(f"原始文件路径: {temp_path}")
        
        # 创建 WAV 临时文件
        wav_fd, wav_path = tempfile.mkstemp(suffix=".wav")
        os.close(wav_fd)  # 关闭文件描述符，让 ffmpeg 使用
        
        # 如果不是 WAV 格式，使用 ffmpeg 转换
        if file_suffix.lower() != ".wav":
            logger.info(f"检测到 {file_suffix} 格式，开始转换为 WAV...")
            if not convert_to_wav(temp_path, wav_path):
                raise HTTPException(status_code=500, detail="音频格式转换失败")
        else:
            # 如果已经是 WAV 格式，直接复制
            shutil.copy2(temp_path, wav_path)
        
        logger.info(f"WAV 文件路径: {wav_path}")
        
        # 读取转换后的 WAV 文件
        samples, sample_rate = read_wave(wav_path)
        logger.info(f"音频处理完成: 样本数={len(samples)}, 采样率={sample_rate}")
        
        # 发送到 Sherpa 进行识别
        result = await send_to_sherpa(samples, sample_rate)
        
        # 根据响应格式返回结果
        response_data = {
            "text": result.strip()
        }
        
        # 如果请求详细格式，可以添加更多信息
        if response_format == "verbose_json":
            response_data.update({
                "task": "transcribe",
                "language": language or "auto",
                "duration": len(samples) / sample_rate,
                "segments": [
                    {
                        "id": 0,
                        "seek": 0,
                        "start": 0.0,
                        "end": len(samples) / sample_rate,
                        "text": result.strip(),
                        "tokens": [],
                        "temperature": temperature or 0.0,
                        "avg_logprob": 0.0,
                        "compression_ratio": 1.0,
                        "no_speech_prob": 0.0
                    }
                ]
            })
        
        logger.info(f"返回结果: {response_data}")
        
        # 返回带有CORS头的响应
        return JSONResponse(
            content=response_data,
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "*",
            }
        )
        
    except Exception as e:
        error_msg = f"转录失败: {str(e)}"
        logger.error(error_msg)
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=error_msg)
        
    finally:
        # 清理临时文件
        for path in [temp_path, wav_path]:
            if path and os.path.exists(path):
                try:
                    os.unlink(path)
                    logger.info(f"已删除临时文件: {path}")
                except Exception as e:
                    logger.warning(f"删除临时文件失败: {e}")

# 健康检查接口
@app.get("/health")
async def health_check():
    try:
        # 测试 Sherpa WebSocket 连接
        uri = f"ws://{SHERPA_WS_HOST}:{SHERPA_WS_PORT}"
        async with websockets.connect(uri) as ws:
            await ws.close()
        
        # 检查 ffmpeg
        ffmpeg_ok = check_ffmpeg()
        
        return {
            "status": "healthy" if ffmpeg_ok else "warning",
            "sherpa_connection": "ok",
            "ffmpeg": "available" if ffmpeg_ok else "not_found"
        }
    except Exception as e:
        return {
            "status": "unhealthy", 
            "sherpa_connection": f"error: {e}",
            "ffmpeg": "available" if check_ffmpeg() else "not_found"
        }

# 模型列表接口（OpenAI API 兼容）
@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [
            {
                "id": "whisper-1",
                "object": "model",
                "created": 1677610602,
                "owned_by": "openai"
            }
        ]
    }

if __name__ == "__main__":
    import uvicorn
    
    # 启动时检查依赖
    if not check_ffmpeg():
        logger.warning("⚠️  未检测到 ffmpeg，请安装后重启服务")
        logger.warning("   macOS: brew install ffmpeg")
        logger.warning("   Ubuntu: sudo apt install ffmpeg")
        logger.warning("   Windows: 从 https://ffmpeg.org/download.html 下载")
    else:
        logger.info("✅ ffmpeg 已就绪")
    
    logger.info("启动语音转录中间件...")
    logger.info("✅ CORS 支持已启用，支持网页调用")
    uvicorn.run(app, host="0.0.0.0", port=8000)
