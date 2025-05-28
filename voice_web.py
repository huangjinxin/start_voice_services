from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
import uvicorn

app = FastAPI()

# HTML 页面内容
html_content = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>语音识别转文字</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Arial', 'Microsoft YaHei', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .container {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
            width: 100%;
            max-width: 800px;
            min-height: 500px;
        }

        .title {
            text-align: center;
            color: #333;
            font-size: 2.5em;
            margin-bottom: 30px;
            font-weight: 300;
            letter-spacing: 2px;
        }

        .control-panel {
            display: flex;
            justify-content: center;
            gap: 20px;
            margin-bottom: 40px;
        }

        .btn {
            padding: 15px 30px;
            font-size: 18px;
            border: none;
            border-radius: 50px;
            cursor: pointer;
            transition: all 0.3s ease;
            font-weight: 600;
            letter-spacing: 1px;
            min-width: 120px;
            position: relative;
            overflow: hidden;
        }

        .btn:before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255,255,255,0.3), transparent);
            transition: left 0.5s;
        }

        .btn:hover:before {
            left: 100%;
        }

        .start-btn {
            background: linear-gradient(45deg, #4CAF50, #45a049);
            color: white;
            box-shadow: 0 4px 15px rgba(76, 175, 80, 0.3);
        }

        .start-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(76, 175, 80, 0.4);
        }

        .start-btn:disabled {
            background: #cccccc;
            cursor: not-allowed;
            transform: none;
            box-shadow: none;
        }

        .stop-btn {
            background: linear-gradient(45deg, #f44336, #d32f2f);
            color: white;
            box-shadow: 0 4px 15px rgba(244, 67, 54, 0.3);
        }

        .stop-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(244, 67, 54, 0.4);
        }

        .stop-btn:disabled {
            background: #cccccc;
            cursor: not-allowed;
            transform: none;
            box-shadow: none;
        }

        .status {
            text-align: center;
            margin-bottom: 30px;
            padding: 15px;
            border-radius: 10px;
            font-weight: 600;
            font-size: 16px;
            transition: all 0.3s ease;
        }

        .status.ready {
            background: linear-gradient(45deg, #e3f2fd, #bbdefb);
            color: #1976d2;
        }

        .status.recording {
            background: linear-gradient(45deg, #ffebee, #ffcdd2);
            color: #d32f2f;
            animation: pulse 2s infinite;
        }

        .status.processing {
            background: linear-gradient(45deg, #fff3e0, #ffe0b2);
            color: #f57c00;
        }

        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.02); }
            100% { transform: scale(1); }
        }

        .text-container {
            position: relative;
        }

        .text-output {
            width: 100%;
            min-height: 200px;
            max-height: 400px;
            padding: 20px;
            border: 2px solid #e0e0e0;
            border-radius: 15px;
            font-size: 16px;
            line-height: 1.6;
            resize: none;
            outline: none;
            transition: all 0.3s ease;
            background: rgba(255, 255, 255, 0.9);
            color: #333;
            overflow-y: auto;
        }

        .text-output:focus {
            border-color: #667eea;
            box-shadow: 0 0 15px rgba(102, 126, 234, 0.2);
        }

        .clear-btn {
            position: absolute;
            top: 10px;
            right: 10px;
            background: #ff6b6b;
            color: white;
            border: none;
            width: 30px;
            height: 30px;
            border-radius: 50%;
            cursor: pointer;
            font-size: 14px;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .clear-btn:hover {
            background: #ff5252;
            transform: scale(1.1);
        }

        .word-count {
            text-align: right;
            margin-top: 10px;
            font-size: 14px;
            color: #666;
        }

        .recording-indicator {
            display: none;
            position: fixed;
            top: 20px;
            right: 20px;
            background: #f44336;
            color: white;
            padding: 10px 20px;
            border-radius: 25px;
            font-weight: 600;
            animation: blink 1s infinite;
            z-index: 1000;
        }

        @keyframes blink {
            0%, 50% { opacity: 1; }
            51%, 100% { opacity: 0.5; }
        }

        .error-message {
            background: #ffebee;
            color: #c62828;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            border-left: 4px solid #f44336;
            display: none;
        }

        @media (max-width: 600px) {
            .container {
                padding: 20px;
                margin: 10px;
            }
            
            .title {
                font-size: 2em;
            }
            
            .control-panel {
                flex-direction: column;
                align-items: center;
            }
            
            .btn {
                width: 200px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="title">🎤 语音识别转文字</h1>
        
        <div class="error-message" id="errorMessage"></div>
        
        <div class="control-panel">
            <button class="btn start-btn" id="startBtn" onclick="startRecording()">
                🎙️ 开始录音
            </button>
            <button class="btn stop-btn" id="stopBtn" onclick="stopRecording()" disabled>
                ⏹️ 停止录音
            </button>
        </div>
        
        <div class="status ready" id="status">准备就绪，点击开始录音</div>
        
        <div class="text-container">
            <textarea class="text-output" id="textOutput" placeholder="识别的文字将显示在这里..."></textarea>
            <button class="clear-btn" onclick="clearText()" title="清空文本">×</button>
            <div class="word-count" id="wordCount">字数: 0</div>
        </div>
    </div>
    
    <div class="recording-indicator" id="recordingIndicator">
        🔴 正在录音...
    </div>

    <script>
        let mediaRecorder = null;
        let audioChunks = [];
        let isRecording = false;

        const startBtn = document.getElementById('startBtn');
        const stopBtn = document.getElementById('stopBtn');
        const status = document.getElementById('status');
        const textOutput = document.getElementById('textOutput');
        const wordCount = document.getElementById('wordCount');
        const recordingIndicator = document.getElementById('recordingIndicator');
        const errorMessage = document.getElementById('errorMessage');

        // 检查浏览器支持
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            showError('您的浏览器不支持录音功能，请使用现代浏览器（Chrome、Firefox、Safari等）');
        }

        async function startRecording() {
            try {
                hideError();
                
                const stream = await navigator.mediaDevices.getUserMedia({ 
                    audio: {
                        echoCancellation: true,
                        noiseSuppression: true,
                        sampleRate: 16000
                    } 
                });
                
                mediaRecorder = new MediaRecorder(stream, {
                    mimeType: 'audio/webm;codecs=opus'
                });
                
                audioChunks = [];
                
                mediaRecorder.ondataavailable = (event) => {
                    if (event.data.size > 0) {
                        audioChunks.push(event.data);
                    }
                };
                
                mediaRecorder.onstop = async () => {
                    const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
                    await sendAudioToServer(audioBlob);
                    
                    // 停止所有音轨
                    stream.getTracks().forEach(track => track.stop());
                };
                
                mediaRecorder.start();
                isRecording = true;
                
                // 更新UI
                startBtn.disabled = true;
                stopBtn.disabled = false;
                status.textContent = '🔴 正在录音中... 请开始说话';
                status.className = 'status recording';
                recordingIndicator.style.display = 'block';
                
            } catch (error) {
                console.error('录音启动失败:', error);
                showError('无法访问麦克风，请检查权限设置');
            }
        }

        function stopRecording() {
            if (mediaRecorder && isRecording) {
                mediaRecorder.stop();
                isRecording = false;
                
                // 更新UI
                startBtn.disabled = false;
                stopBtn.disabled = true;
                status.textContent = '🔄 正在处理音频，请稍候...';
                status.className = 'status processing';
                recordingIndicator.style.display = 'none';
            }
        }

        async function sendAudioToServer(audioBlob) {
            try {
                const formData = new FormData();
                formData.append('file', audioBlob, 'recording.webm');
                formData.append('model', 'whisper-1');
                formData.append('response_format', 'json');
                
                const response = await fetch('http://localhost:8000/v1/audio/transcriptions', {
                    method: 'POST',
                    headers: {
                        'Authorization': 'Bearer 123'
                    },
                    body: formData
                });
                
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }
                
                const result = await response.json();
                
                if (result.text && result.text.trim()) {
                    appendText(result.text.trim());
                    status.textContent = '✅ 识别完成！可以继续录音';
                    status.className = 'status ready';
                } else {
                    status.textContent = '⚠️ 未识别到语音内容，请重试';
                    status.className = 'status ready';
                }
                
            } catch (error) {
                console.error('音频处理失败:', error);
                showError(`音频处理失败: ${error.message}`);
                status.textContent = '❌ 处理失败，请重试';
                status.className = 'status ready';
            }
        }

        function appendText(text) {
            const currentText = textOutput.value;
            const newText = currentText ? currentText + ' ' + text : text;
            textOutput.value = newText;
            
            // 自动调整高度
            textOutput.style.height = 'auto';
            textOutput.style.height = Math.min(textOutput.scrollHeight, 400) + 'px';
            
            // 滚动到底部
            textOutput.scrollTop = textOutput.scrollHeight;
            
            updateWordCount();
        }

        function clearText() {
            textOutput.value = '';
            textOutput.style.height = '200px';
            updateWordCount();
        }

        function updateWordCount() {
            const text = textOutput.value;
            const count = text.length;
            wordCount.textContent = `字数: ${count}`;
        }

        function showError(message) {
            errorMessage.textContent = message;
            errorMessage.style.display = 'block';
        }

        function hideError() {
            errorMessage.style.display = 'none';
        }

        // 监听文本框变化
        textOutput.addEventListener('input', updateWordCount);
        
        // 监听键盘快捷键
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey || e.metaKey) {
                if (e.key === 'Enter' && !isRecording) {
                    e.preventDefault();
                    startRecording();
                } else if (e.key === 'Escape' && isRecording) {
                    e.preventDefault();
                    stopRecording();
                }
            }
        });

        // 页面加载完成后的提示
        window.addEventListener('load', () => {
            console.log('🎤 语音识别应用已就绪！');
            console.log('快捷键: Ctrl+Enter 开始录音, Esc 停止录音');
        });
    </script>
</body>
</html>
"""

@app.get("/", response_class=HTMLResponse)
async def get_home():
    return html_content

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "voice_recognition_web"}

if __name__ == "__main__":
    print("🎤 启动语音识别网页应用...")
    print("📱 访问地址: http://localhost:6666")
    print("🎯 确保语音识别服务运行在 http://localhost:8000")
    print("⌨️  快捷键: Ctrl+Enter 开始录音, Esc 停止录音")
    print("-" * 50)
    
    uvicorn.run(app, host="0.0.0.0", port=8888)
