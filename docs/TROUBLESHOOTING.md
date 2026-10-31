# 故障排查指南（Troubleshooting）

本文汇总在 VMware Workstation 中安装 macOS Tahoe 26 时的常见问题与定位方法。

## 1. 如何查看虚拟机日志

虚拟机运行日志位于虚拟机目录下的 `vmware.log`（历史日志会滚动为 `vmware-0.log`、`vmware-1.log` 等）。

```powershell
# 查看监控模式
Select-String -Path ".\vmware.log" -Pattern "Monitor Mode"

# 查看致命错误
Select-String -Path ".\vmware.log" -Pattern "unrecoverable|panic|noslot|fail"
```

---

## 2. 监控模式：ULM 与 CPL0

- **`Monitor Mode: CPL0`**：VMware 直接使用 Intel VT-x，性能与兼容性最佳。
- **`Monitor Mode: ULM`**：检测到 Hyper-V，VMware 走用户级监控，macOS 通常会卡在 Apple Logo。

**解决**：以管理员运行 `scripts/hyperv-off.ps1`，重启电脑。

确认 Hyper-V 是否被 CPUID 检测到：

```powershell
Select-String -Path ".\vmware.log" -Pattern "Hyper-V detected"
```

---

## 3. 错误 -18“产品不兼容”

`virtualHW.version` 数值超过当前 VMware 支持的上限。Workstation 26 最高支持硬件版本 **22**。

**解决**：把 vmx 中改为 `virtualHW.version = "22"`。可对照已有正常虚拟机的 vmx 确认。

---

## 4. No PCIe slot available（网卡 / 设备注册失败）

完整报错：

```
[msg.pci.noslotavail] No PCIe slot available for Ethernet0.
E1000PCI: failed to register e1000e device.
```

随后常伴随 `0xc0000005 access violation` 崩溃。

**根因**：vmx 缺少 `pciBridge` 配置，或自动分配的槽位与 PCIe 根端口冲突。

**解决**：使用仓库模板，补全 `pciBridge0/4/5/6/7`，并为每个 PCI 设备显式设置 `pciSlotNumber`：

```
svga=16  pciBridge0=17  pciBridge4/5/6/7=21/22/23/24
usb=32  ethernet0=33  ehci=35  usb_xhci=36  sata0=37
```

---

## 5. 卡在 Apple Logo / 进度条不动

判断方法：观察 `vmware-vmx` 进程的 CPU 时间，若长时间几乎不增长且画面无变化，基本可判定为引导挂起。

**常见原因与处理**：

1. Hyper-V / ULM 模式 → 关闭 Hyper-V（最常见）。
2. 3D 加速问题 → 设置 `mks.enable3d = "FALSE"`。
3. vCPU 过多或声卡等设备干扰 → 先用 2 vCPU，关闭声卡（`sound.present = "FALSE"`）。
4. CPU 不支持 AVX2 → macOS 13 及以上无法安装，需更换支持 AVX2 的 CPU，或改装 macOS 12。

---

## 6. 恢复镜像下载失败（unexpected EOF）

直连 Apple CDN 时连接被中断，常在 1MB 处失败。

**解决**：配置代理环境变量后重新下载：

```powershell
$env:HTTP_PROXY  = "http://127.0.0.1:7893"
$env:HTTPS_PROXY = "http://127.0.0.1:7893"
```

---

## 7. vhv / vpmc 启动失败

- `模块 'VPMC' 启动失败`：ULM 不支持虚拟化性能计数器。
- `此平台不支持虚拟化的 Intel VT-x/EPT`：ULM 不支持嵌套硬件虚拟化。

**解决**：移除 `vhv.enable`、`vpmc.enable`，并关闭 Hyper-V 回到 CPL0；普通 macOS 客户机并不需要这两个选项。

---

## 8. 抹盘 / 安装阶段

- **找不到目标磁盘**：先在“磁盘工具”中对 80GB 空白盘执行“抹掉”（APFS + GUID）。
- **选错磁盘**：切勿抹掉 2.3GB 的恢复盘；目标是 80GB 的 `tahoe-disk`。
- **安装中断/下载慢**：保持网络稳定，必要时在客户机内配置代理；安装会自动重启数次，属正常现象。
- **重启后又回到恢复界面**：检查启动顺序，或在系统安装完成后移除恢复盘。

---

## 9. VMware Tools 安装

- 确认 VMware 目录存在 `darwin.iso`（Unlocker 会复制）。
- 挂载后如系统拦截安装，在“隐私与安全性”中允许对应安装器/内核扩展。
- 安装后重启，分辨率与共享文件夹才会生效。

---

## 10. 恢复 Hyper-V（重新启用 WSL2 / Docker）

```powershell
# 管理员 PowerShell
bcdedit /set hypervisorlaunchtype auto
# 如需，重新启用“虚拟机平台”功能
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
# 重启
```

重启后 VMware 会回到 ULM 模式，macOS 虚拟机将再次无法正常引导，需自行权衡。

---

如仍无法解决，请携带 `vmware.log` 中的具体报错，通过 [CONTACT.md](CONTACT.md) 中的渠道联系开发者。
