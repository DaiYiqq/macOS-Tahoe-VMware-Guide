#Requires -RunAsAdministrator
<#
.SYNOPSIS
    运行 DrDonk Unlocker 解锁 VMware 的 macOS 客户机选项，并在前后各做一次 check。
.NOTES
    请先从 https://github.com/DrDonk/unlocker 下载并解压 Unlocker，
    然后把下面的 $unlockerWindowsDir 指向解压目录下的 windows 文件夹。
    作者：戴亿 (DaiYi)，MIT 许可证。
#>
$ErrorActionPreference = "Continue"

# ===== 按实际解压位置修改 =====
$unlockerWindowsDir = "D:\COLORFUL\macOS-VM\tools\unlocker\windows"
# ==============================

Get-Process -Name check, unlock -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Set-Location $unlockerWindowsDir

Write-Output "=== CHECK BEFORE ==="
cmd /c "check.exe < nul"
Write-Output "=== UNLOCK ==="
cmd /c "unlock.exe < nul"
Write-Output ("unlock exit = " + $LASTEXITCODE)
Write-Output "=== CHECK AFTER ==="
cmd /c "check.exe < nul"
Write-Output "=== DONE ==="
