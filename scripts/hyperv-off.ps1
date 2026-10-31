#Requires -RunAsAdministrator
<#
.SYNOPSIS
    关闭 Windows 的 Hyper-V / VBS / 内存完整性，让 VMware Workstation
    回到 CPL0 原生监控模式（macOS 客户机正常引导的必要条件）。
.DESCRIPTION
    操作内容：
      1. bcdedit /set hypervisorlaunchtype off
      2. 注册表禁用 VBS、HVCI、Credential Guard
      3. 禁用 Hyper-V / 虚拟机平台 / Windows 虚拟机监控程序 / 沙盒等可选功能
    全部使用 -NoRestart，脚本结束后请手动重启电脑使设置生效。
.NOTES
    作者：戴亿 (DaiYi)
    许可证：MIT
.LINK
    恢复方法：bcdedit /set hypervisorlaunchtype auto 然后重启
#>
$ErrorActionPreference = "Continue"

Write-Output "=== 1. bcdedit hypervisorlaunchtype off ==="
bcdedit /set hypervisorlaunchtype off

Write-Output "=== 2. Disable VBS / Credential Guard via registry ==="
$dg = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
New-Item -Path $dg -Force | Out-Null
New-ItemProperty -Path $dg -Name EnableVirtualizationBasedSecurity -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $dg -Name RequirePlatformSecurityFeatures -Value 0 -PropertyType DWord -Force | Out-Null

$hvci = Join-Path $dg "Scenarios\HypervisorEnforcedCodeIntegrity"
New-Item -Path $hvci -Force | Out-Null
New-ItemProperty -Path $hvci -Name Enabled -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $hvci -Name WasEnabledBy -Value 0 -PropertyType DWord -Force | Out-Null

$lsa = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
New-ItemProperty -Path $lsa -Name LsaCfgFlags -Value 0 -PropertyType DWord -Force | Out-Null

Write-Output "=== 3. Disable Windows optional features (no restart) ==="
$features = @(
    "Microsoft-Hyper-V-All",
    "Microsoft-Hyper-V",
    "Microsoft-Hyper-V-Hypervisor",
    "Microsoft-Hyper-V-Services",
    "Microsoft-Hyper-V-Management-Clients",
    "VirtualMachinePlatform",
    "HypervisorPlatform",
    "Containers-DisposableClientVM"
)
foreach ($f in $features) {
    $st = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
    if ($st) {
        Write-Output ("{0} : {1}" -f $f, $st.State)
        if ($st.State -eq "Enabled") {
            Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Output "  -> disabled (pending restart)"
        }
    }
}

Write-Output "=== Done. 请重启电脑使设置生效。 ==="
