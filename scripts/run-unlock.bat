@echo off
REM 运行 DrDonk Unlocker 解锁 macOS 客户机选项。
REM 请右键“以管理员身份运行”，并先把下面的目录改成你解压 unlocker 的 windows 目录。
set "UNLOCKER_DIR=D:\COLORFUL\macOS-VM\tools\unlocker\windows"
cd /d "%UNLOCKER_DIR%"
echo ==== CHECK BEFORE ====
check.exe < nul
echo.
echo ==== UNLOCK ====
unlock.exe < nul
echo UNLOCK_EXIT=%errorlevel%
echo.
echo ==== CHECK AFTER ====
check.exe < nul
echo ==== DONE ====
pause
