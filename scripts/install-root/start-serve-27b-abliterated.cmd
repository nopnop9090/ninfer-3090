@echo off
setlocal
if defined NINFER_ROOT (
  set "ROOT=%NINFER_ROOT%"
) else if exist "%~dp0bin\ninfer-serve.exe" (
  set "ROOT=%~dp0"
) else (
  echo Set NINFER_ROOT to your install directory containing bin\ and models\
  echo Or copy this script next to bin\ and models\.
  exit /b 1
)
cd /d "%ROOT%\bin" || exit /b 1
ninfer-serve.exe ..\models\qwen3_6_27b_huihui_abliterated.ninfer ^
  --model-id qwen3.6-27b-huihui-abliterated ^
  --host 127.0.0.1 --port 8080 ^
  --max-context 65536 --prefill-chunk 128 --kv-dtype int8 ^
  --mtp-draft-tokens 3 --lm-head-draft ^
  --prompt-lookup-tokens 15 --prompt-lookup-min-match 4 ^
  --prompt-lookup-auto --prompt-lookup-min-context 1000
