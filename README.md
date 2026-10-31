# 在 VMware Workstation 中安装 macOS Tahoe 26（Windows 宿主机完整方案）

> 一套在 **Windows 11 + VMware Workstation 26** 上安装最新版 **macOS Tahoe 26** 的完整可复现方案。
> 技术路线：**DrDonk Unlocker 解锁 + Apple 官方恢复镜像（recoveryOS）联网安装**，不使用任何第三方破解镜像，全部文件来自 Apple 官方与开源工具。

---

## 目录

- [一、方案概述](#一方案概述)
- [二、环境要求](#二环境要求)
- [三、目录结构](#三目录结构)
- [四、完整安装步骤](#四完整安装步骤)
  - [步骤 0：环境探查](#步骤-0环境探查)
  - [步骤 1：下载并运行 Unlocker 解锁](#步骤-1下载并运行-unlocker-解锁)
  - [步骤 2：下载 Apple 官方恢复镜像](#步骤-2下载-apple-官方恢复镜像)
  - [步骤 3：转换恢复盘并创建系统盘](#步骤-3转换恢复盘并创建系统盘)
  - [步骤 4：创建虚拟机（vmx 配置）](#步骤-4创建虚拟机vmx-配置)
  - [步骤 5：关闭 Hyper-V / VBS（关键）](#步骤-5关闭 hyper-v--vbs关键)
  - [步骤 6：抹盘并联网安装系统](#步骤-6抹盘并联网安装系统)
  - [步骤 7：安装 VMware Tools](#步骤-7安装-vmware-tools)
- [五、踩坑记录（重要）](#五踩坑记录重要)
- [六、常见问题与故障排查](#六常见问题与故障排查)
- [七、开发者信息](#七开发者信息)
- [八、开源协议](#八开源协议)

---

## 一、方案概述

VMware Workstation 在非 Apple 硬件上默认**隐藏 macOS 客户机选项**，需要用开源的 **DrDonk Unlocker** 给 VMware 二进制文件打补丁，解锁 Apple SMC 与 macOS 客户机类型。

解锁后，不直接下载体积庞大的成品系统镜像，而是通过 **DrDonk recoveryOS** 从 Apple 官方服务器拉取 **BaseSystem 恢复镜像（约 916MB）**，转换成 VMDK 作为引导盘；虚拟机启动后进入官方恢复界面，再由安装器联网下载完整 macOS（约 14–16GB）并安装。

```
解锁 VMware  →  下载恢复镜像  →  转 VMDK + 建系统盘  →  配 vmx
           →  关 Hyper-V  →  恢复界面抹盘  →  联网安装 Tahoe 26
```

---

## 二、环境要求

### 硬件

| 项目 | 要求 | 本项目实测环境 |
|---|---|---|
| CPU | **Intel 平台**（对 macOS 客户机兼容性最好）；macOS 13 及以上要求支持 **AVX2** | Intel Core i5-12450H（8 核 12 线程，支持 AVX2） |
| 内存 | 建议 16GB，给虚拟机分配 8GB | 物理 15.7GB，虚拟机分配 8GB |
| 硬盘 | 至少预留 40GB 空闲（稀疏磁盘，实际按需增长） | 安装在 D 盘 |
| 显卡 | 支持基础显示即可（本方案默认关闭 3D 加速） | — |

> AMD CPU 也可安装，但部分版本需要额外处理 CPUID，坑更多，本教程以 Intel 为准。

### 软件

- **Windows 11**（Build 26300 实测通过）
- **VMware Workstation 26.0.0**（硬件版本最高 22；Workstation 16/17 同理，需对应版本的 Unlocker）
- **DrDonk Unlocker v4.2.8**（支持 VMware 26H1 与 macOS 26）
- **DrDonk recoveryOS 1.0.3**
- **QEMU 11.1.0**（提供 `qemu-img` 用于镜像格式转换）

### 工具下载地址

| 工具 | 地址 |
|---|---|
| DrDonk Unlocker | https://github.com/DrDonk/unlocker/releases/download/v4.2.8/unlocker428.zip |
| DrDonk recoveryOS | https://github.com/DrDonk/recoveryOS/releases/download/1.0.3/recoveryOS-1.0.3.zip |
| QEMU (Windows) | https://qemu.weilnetz.de/w64/ （选对应日期的 `qemu-w64-setup-*.exe`） |
| macrecovery.py（备用） | https://raw.githubusercontent.com/acidanthera/OpenCorePkg/master/Utilities/macrecovery/macrecovery.py |

---

## 三、目录结构

本仓库**只包含脚本、配置模板与文档**，不包含虚拟磁盘、安装包等大文件（见 `.gitignore`）。

```
.
├── README.md                     # 本教程
├── LICENSE                       # MIT 开源协议
├── .gitignore                    # 排除 vmdk/vmem/lck/日志等
├── scripts/
│   ├── hyperv-off.ps1            # 一键关闭 Hyper-V / VBS（管理员）
│   ├── post-reboot-start.ps1     # 重启后启动 VM 并验证监控模式
│   ├── run-unlock.ps1            # 运行 Unlocker（管理员）
│   └── run-unlock.bat            # 同上的 CMD 版本
├── vm-template/
│   └── macOS Tahoe 26.vmx        # 清理后的通用虚拟机配置模板
└── docs/
    ├── TROUBLESHOOTING.md        # 故障排查详解
    └── CONTACT.md                # 开发者联系方式
```

实际工作机上的运行目录（示例）：

```
D:\COLORFUL\macOS-VM\
├── macOS-Tahoe\                  # 虚拟机目录
│   ├── macOS Tahoe 26.vmx
│   ├── tahoe-recovery.vmdk       # 恢复引导盘（2.3GB，需自行生成）
│   ├── tahoe-disk.vmdk           # 80GB 稀疏系统盘（需自行生成）
│   └── vmware.log
├── tools\
│   ├── unlocker\                 # 解压的 Unlocker
│   ├── recoveryOS\               # 解压的 recoveryOS
│   ├── qemu\                     # QEMU
│   └── macrecovery.py
└── downloads\                    # 安装包与压缩包
```

---

## 四、完整安装步骤

### 步骤 0：环境探查

先确认 VMware 安装位置与版本、CPU、内存、磁盘可写性：

```powershell
# VMware 版本与进程
Get-Process vmware, vmware-vmx -ErrorAction SilentlyContinue
& "<VMware目录>\vmware.exe"  # 图形界面中查看版本

# CPU 是否支持 AVX2（macOS 13+ 必需）
Get-CimInstance Win32_Processor | Select-Object Name

# 确认当前监控模式（启动过任意 VM 后在 vmware.log 中查看）
Select-String -Path "<VM目录>\vmware.log" -Pattern "Monitor Mode"
```

> **权限提示**：若 VMware 装在磁盘根目录（如 `D:\`），普通用户可能无法在根目录写入。请把工作目录建在可写的用户目录下（本项目用 `D:\COLORFUL\`）。

---

### 步骤 1：下载并运行 Unlocker 解锁

1. 完全关闭 VMware Workstation 及所有 `vmware-vmx` 进程。
2. 从上面的地址下载 `unlocker428.zip` 并解压。
3. **以管理员身份**运行解锁（可直接用本仓库脚本，先编辑脚本里的路径）：

```powershell
# 管理员 PowerShell
.\scripts\run-unlock.ps1
```

或使用 CMD 版本（右键 `run-unlock.bat` → 以管理员身份运行）。

补丁会完成以下工作：

- 修补 `vmwarebase.dll` 中的客户机标志，解锁 macOS 客户机类型；
- 给 `vmware-vmx.exe` 等写入 Apple SMC 的 **OSK 密钥**；
- 复制 `darwin.iso`、`darwinPre15.iso`（macOS 版 VMware Tools）到 VMware 目录；
- 原始文件自动备份到 `backup\` 目录。

4. 用 `check.exe` 验证，确认所有目标文件状态为 **Patched**。

解锁后支持的客户机字符串覆盖 `darwin10-64` 到 **`darwin26-64`**（对应 macOS Tahoe 26）。

---

### 步骤 2：下载 Apple 官方恢复镜像

1. 安装 QEMU（recoveryOS 依赖 `qemu-img`），可使用下载的 NSIS 安装包静默安装：

```powershell
# 示例：静默安装到指定目录
.\qemu-w64-setup-*.exe /S /D=D:\COLORFUL\macOS-VM\tools\qemu
```

2. 解压 `recoveryOS-1.0.3.zip`，运行其交互式入口，按菜单选择：
   - 系统版本：**Tahoe（macOS 26）**
   - 输出格式：**VMDK**

3. 脚本会从 Apple CDN（`oscdn.apple.com`）下载 `BaseSystem.dmg`（约 916MB）。

> **网络问题（实测）**：在国内直连 Apple CDN 可能在 1MB 处报 `unexpected EOF`。
> 解决方法：配置本地代理后再下载（示例代理端口按实际修改）：
> ```powershell
> $env:HTTP_PROXY  = "http://127.0.0.1:7893"
> $env:HTTPS_PROXY = "http://127.0.0.1:7893"
> ```
> 走代理后约 45 秒可下完 916MB。

---

### 步骤 3：转换恢复盘并创建系统盘

若 recoveryOS 的交互式格式选择未能执行（如 stdin 被重定向），可手动用 `qemu-img` 转换：

```powershell
# DMG 转 VMDK（monolithicSparse）
& "<QEMU目录>\qemu-img.exe" convert -O vmdk `
    ".\downloads\tahoe.dmg" `
    ".\macOS-Tahoe\tahoe-recovery.vmdk"

# 创建 80GB 稀疏系统盘（-t 0 = 单文件稀疏，初始仅约 10MB）
& "<VMware目录>\vmware-vdiskmanager.exe" -c -s 80GB `
    -a sata -t 0 `
    ".\macOS-Tahoe\tahoe-disk.vmdk"
```

- `tahoe-recovery.vmdk`：恢复引导盘（约 2.3GB），接到 SATA 0:0；
- `tahoe-disk.vmdk`：空白系统盘（80GB 稀疏），接到 SATA 0:1。

---

### 步骤 4：创建虚拟机（vmx 配置）

可直接使用本仓库的 [`vm-template/macOS Tahoe 26.vmx`](vm-template/macOS%20Tahoe%2026.vmx)，复制到虚拟机目录并按实际文件名调整。关键配置：

| 参数 | 值 | 说明 |
|---|---|---|
| `guestOS` | `darwin26-64` | macOS Tahoe 26 |
| `virtualHW.version` | **`22`** | Workstation 26 实际最高支持 22，**不是 26** |
| `firmware` | `efi` | 必须 UEFI |
| `smc.version` | `0` | 解锁后的 SMC 设备 |
| `numvcpus` / `memsize` | `2` / `8192` | 2 核 8GB（可按主机调整） |
| `ethernet0.virtualDev` | `e1000e` | 网卡，NAT |
| `mks.enable3d` | `FALSE` | 关闭 3D，避免引导异常 |

**PCI 槽位必须显式固定**（否则会报 `No PCIe slot available`，详见踩坑记录）：

```
svga=16  pciBridge0=17  pciBridge4/5/6/7=21/22/23/24
usb=32  ethernet0=33  ehci=35  usb_xhci=36  sata0=37
```

并配置启动顺序优先恢复盘：`bios.hddOrder = "sata0:0,sata0:1"`。

---

### 步骤 5：关闭 Hyper-V / VBS（关键）

Windows 11 默认开启 Hyper-V / 基于虚拟化的安全（VBS），此时 VMware 只能运行在 **ULM 用户级监控模式**，会导致 macOS **卡在 Apple Logo 无法进入系统**。必须关闭以回到 **CPL0 原生模式**。

**以管理员身份**运行本仓库脚本：

```powershell
.\scripts\hyperv-off.ps1
```

脚本会：

1. 执行 `bcdedit /set hypervisorlaunchtype off`；
2. 注册表禁用 VBS、内存完整性（HVCI）、Credential Guard；
3. 禁用 Hyper-V、虚拟机平台、Windows 虚拟机监控程序、沙盒等功能（不自动重启）。

然后**重启电脑**使设置生效。重启后可运行：

```powershell
.\scripts\post-reboot-start.ps1
```

确认 `vmware.log` 中已变为 **`Monitor Mode: CPL0`**。

> 恢复方法（想重新使用 WSL2 / Docker 时）：
> `bcdedit /set hypervisorlaunchtype auto`，再重启即可。

---

### 步骤 6：抹盘并联网安装系统

1. 启动虚拟机，进入 **macOS 恢复（macOS 实用工具）界面**。
2. 选择 **“磁盘工具”（Disk Utility）**：
   - 选中 **80GB 的 `tahoe-disk`**（**切勿选 2.3GB 的恢复盘**）；
   - 点“抹掉”，名称随意（如 `Macintosh HD`），格式选 **APFS**，方案 **GUID 分区图**。
3. 关闭磁盘工具，回到实用工具界面，选择 **“安装 macOS Tahoe”**。
4. 按提示选择刚抹好的磁盘，安装器会**联网下载完整系统（约 14–16GB）**，期间会**自动重启数次**，请耐心等待。
5. 安装完成后按向导完成语言、账户等初始设置。

> 若虚拟机内下载过慢或断连：可在客户机网络设置中配置代理（宿主机代理需先开启“允许局域网连接”）。

---

### 步骤 7：安装 VMware Tools

系统装好后：

1. 关机或在运行中，**断开/移除恢复盘 `tahoe-recovery.vmdk`**；
2. 挂载 Unlocker 复制的 `darwin.iso`（位于 VMware 安装目录）；
3. 在 macOS 中打开挂载的光盘，运行 **Install VMware Tools**；
4. 按提示安装并重启，即可获得自适应分辨率、共享文件夹、时间同步等功能。

---

## 五、踩坑记录（重要）

以下问题均在本项目实测中遇到并解决，复现可直接对照：

| # | 错误现象 | 根因 | 解决 |
|---|---|---|---|
| 1 | 错误 `-18`“产品不兼容” | `virtualHW.version` 写成了 `26` | 改为 Workstation 实际支持的 **`22`** |
| 2 | `No PCIe slot available for Ethernet0`，随后 `0xc0000005` 崩溃 | vmx 缺 `pciBridge`，自动分配的 PCI 槽位冲突 | 补全 4 个 `pciBridge` 并显式固定全部槽位 |
| 3 | 卡在 Apple Logo、进度条几乎不动、CPU 空闲 | Hyper-V 导致 VMware 处于 ULM 模式 | 关闭 Hyper-V/VBS 后重启，回到 CPL0 |
| 4 | `VPMC` 模块启动失败 | ULM 模式不支持虚拟化性能计数器 | 关闭 Hyper-V；或移除 `vpmc.enable` |
| 5 | “此平台不支持虚拟化的 Intel VT-x/EPT” | ULM 模式下 `vhv.enable` 不可用 | 关闭 Hyper-V |
| 6 | 下载在 1MB 处 `unexpected EOF` | 直连 Apple CDN 被中断 | 配置代理后重新下载 |
| 7 | 磁盘根目录建文件夹 `Access Denied` | 根目录普通用户无写权限 | 工作目录放到可写的用户目录 |

---

## 六、常见问题与故障排查

更详细的排查步骤（含黑屏、重启循环、Tools 安装失败、网络代理等）见：

**[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**

快速自查清单：

- [ ] `vmware.log` 中 `Monitor Mode` 是否为 **CPL0**？
- [ ] `virtualHW.version` 是否为 **22**？
- [ ] vmx 是否包含完整 `pciBridge` 与固定槽位？
- [ ] 抹盘时是否选中了 **80GB 系统盘**而非恢复盘？
- [ ] 网络是否需要代理才能访问 Apple CDN？

---

## 七、开发者信息

本项目由 **戴亿（DaiYi）** 开发与维护。

| 渠道 | 联系方式 |
|---|---|
| 开发者 | **戴亿（DaiYi）** |
| QQ | 1703205607 |
| QQ 邮箱 | 1703205607@qq.com |
| Gmail | daiy91004@gmail.com |
| 抖音 | daiyi091004 |
| Telegram | [@DaiYi520](https://t.me/DaiYi520) |
| GitHub | [DaiYiqq](https://github.com/DaiYiqq) |

完整联系方式另见 **[docs/CONTACT.md](docs/CONTACT.md)**。欢迎 Issue 与 PR。

---

## 八、开源协议

本项目基于 **[MIT License](LICENSE)** 开源，允许任何人自由使用、复制、修改、合并、发布、分发与再授权，唯需保留原版权声明与许可声明。

本项目仅提供技术方法与脚本，不包含、不分发任何 Apple 专有软件或系统镜像；macOS 的版权归 Apple Inc. 所有，请在遵守 Apple 许可协议的前提下使用。

---

> 如果本项目对你有帮助，欢迎在 GitHub 上 Star 支持，并通过上方渠道与开发者交流。
