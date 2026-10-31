<#
.SYNOPSIS
    重启回来后启动 macOS 虚拟机，验证监控模式并截图。
.NOTES
    请根据实际情况修改下面的路径变量。作者：戴亿 (DaiYi)，MIT 许可证。
#>
$ErrorActionPreference = "Continue"

# ===== 可按实际环境修改的路径变量 =====
$vmwareDir = "D:\"
$vmDir     = "D:\COLORFUL\macOS-VM\macOS-Tahoe"
$vmx       = Join-Path $vmDir "macOS Tahoe 26.vmx"
$shotOut   = "D:\COLORFUL\macOS-VM\post-reboot-screen.png"
$vmrun     = Join-Path $vmwareDir "vmrun.exe"
# =====================================

Write-Output "=== Clean locks ==="
Get-ChildItem $vmDir -Filter "*.lck" -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $vmDir "vmware.log") -Force -ErrorAction SilentlyContinue

Write-Output "=== Start VM ==="
& $vmrun -T ws start $vmx
Write-Output ("vmrun exit = " + $LASTEXITCODE)

Start-Sleep -Seconds 30

Write-Output "=== Monitor mode check (期望 CPL0) ==="
$log = Join-Path $vmDir "vmware.log"
if (Test-Path $log) {
    Get-Content $log -Encoding UTF8 |
        Select-String "Monitor Mode" |
        Select-Object -First 1 |
        ForEach-Object { $_.Line }
}

Write-Output "=== Process check ==="
Get-Process -Name "vmware-vmx" -ErrorAction SilentlyContinue |
    Select-Object Id, @{n='MB';e={[math]::Round($_.WorkingSet64/1MB,0)}}, CPU

Write-Output "=== Screenshot ==="
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$b = [Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object Drawing.Bitmap $b.Width, $b.Height
$g = [Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Location, [Drawing.Point]::Empty, $b.Size)
$bmp.Save($shotOut, [Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Output ("screenshot saved: " + $shotOut)
