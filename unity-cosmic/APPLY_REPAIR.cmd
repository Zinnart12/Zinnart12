@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tools\repair-urp.ps1"
if errorlevel 1 (
  echo Repair failed. Read the error above and keep Unity closed before retrying.
  pause
  exit /b 1
)
echo Repair applied. Open this project with Unity 6000.6.5f1 and wait for compilation.
pause
