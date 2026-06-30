# Codex Halo-Windows

一个为 Codex 准备的 Windows 桌面状态光环。

Codex Halo 会在屏幕角落显示一个轻量的悬浮光环，用颜色反馈 Codex 当前状态：空闲、思考、执行工具、完成。它适合长期放在桌面上，不弹窗、不打扰、不需要保留终端窗口，让你用余光就能知道 Codex 是否还在工作。

> Unofficial Windows desktop status halo for Codex.

---

## 项目简介

使用 Codex 时，很多任务会在后台持续运行：模型思考、执行命令、读取文件、等待工具返回、完成回复。默认情况下，你通常需要回到 Codex 窗口或终端里确认它到底还在不在运行。

Codex Halo 解决的是这个小但真实的问题：

- Codex 正在思考时，光环变为橙色；
- Codex 正在执行工具或命令时，光环变为蓝色；
- Codex 完成当前任务后，短暂变为绿色；
- 没有任务时，保持低存在感的灰白色。

它不是聊天客户端，也不是 Codex 插件商店里的官方插件。它只是一个本地 Windows 桌面辅助工具，通过读取 Codex 本机 session 事件日志来判断状态。

---

## 功能亮点

- **桌面悬浮状态光环**  
  一个轻量的窗口常驻在桌面角落，用颜色展示 Codex 状态。

- **更准确的事件检测**  
  不靠 CPU 波动猜测状态，而是读取 Codex 本地 session JSONL 中的任务事件。

- **无终端后台运行**  
  启动、停止、移动都通过快捷方式完成。启动后不会一直开着终端窗口。

- **一键启动 / 停止 / 移动**  
  文件夹根目录提供三个入口：`启动 Codex Halo`、`停止 Codex Halo`、`移动 Codex Halo`。

- **可移动位置**  
  通过移动模式拖动光环，松开鼠标后保存位置，下次启动会自动恢复。

- **适合便携分发**  
  支持复制到其他电脑后运行 `Install-CodexHalo.cmd` 重建本机快捷方式。

- **本地运行，不上传数据**  
  所有检测都发生在本机，没有网络请求逻辑。

---

## 状态颜色

| 状态 | 说明 | 颜色 |
| --- | --- | --- |
| Idle | 当前没有检测到 Codex 任务 | 灰白 |
| Thinking | Codex 已开始处理任务或正在生成回复 | 橙色 |
| Executing | Codex 正在执行工具调用、命令或文件操作 | 蓝色 |
| Completed | 当前任务已完成，随后自动回到 Idle | 绿色 |

当前版本主要覆盖 Codex 使用中最常见、也最有价值的四类状态。

---

## 运行环境

- Windows 10 / Windows 11
- 已安装并使用 Codex
- Windows PowerShell 5.1 或 PowerShell 7

Codex Halo 会读取当前用户目录下的 Codex session 日志：

```text
C:\Users\<你的用户名>\.codex\sessions\...\*.jsonl
```

如果你使用的是不同的 Codex 版本、不同安装方式，或 Codex 未来更改了 session 日志格式，检测脚本可能需要调整。

---

## 下载与安装

### 使用 Release 压缩包

推荐普通用户使用这种方式。

1. 到 GitHub Release 下载 `Codex-Halo.zip`。
2. 解压到你想保存的位置，例如桌面。
3. 进入 `Codex Halo` 文件夹。
4. 第一次使用先双击：

```text
Install-CodexHalo.cmd
```

这个脚本会根据当前电脑的真实路径重新生成快捷方式。

5. 然后双击：

```text
启动 Codex Halo
```

---

## 使用方式

### 启动

双击：

```text
启动 Codex Halo
```

启动后会发生两件事：

1. 打开 `codex-halo.exe` 显示桌面光环；
2. 在后台启动 PowerShell 监控脚本，监听 Codex session 事件。

整个过程不会保留一个可见终端窗口。

### 停止

双击：

```text
停止 Codex Halo
```

停止脚本会通知后台监控退出，并清理残留的 Halo 窗口进程。

### 移动位置

双击：

```text
移动 Codex Halo
```

屏幕会出现半透明移动层：

- 按住鼠标左键拖动光环；
- 松开鼠标后保存位置；
- 按 `Esc` 取消移动。

位置会保存到：

```text
_internal\position.txt
```

下次启动时会自动恢复到上次保存的位置。

---

## 推荐目录结构

Release 包建议保持下面的结构：

```text
Codex Halo/
├─ Install-CodexHalo.cmd
├─ README.md
├─ 启动 Codex Halo.lnk
├─ 停止 Codex Halo.lnk
├─ 移动 Codex Halo.lnk
└─ _internal/
   ├─ codex-halo.exe
   ├─ halo-icon.svg
   ├─ Start-CodexHalo.ps1
   ├─ Stop-CodexHalo.ps1
   ├─ Move-CodexHalo.ps1
   ├─ Rebuild-Shortcuts.ps1
   ├─ Rebuild-Shortcuts.cmd
   └─ position.txt
```

说明：

- 根目录只放用户常用入口和说明文档；
- `_internal` 存放实际程序和脚本；
- `.lnk` 快捷方式包含绝对路径，不适合直接跨电脑使用；
- 换电脑、换盘符、换文件夹后，请重新运行 `Install-CodexHalo.cmd`。

---

## 为什么换电脑后要运行安装脚本

Windows 的 `.lnk` 快捷方式保存的是绝对路径。例如：

```text
F:\Users\XXX\Desktop\Codex Halo\_internal\Start-CodexHalo.ps1
```

复制到另一台电脑后，用户名、盘符、桌面路径都可能不同，所以原来的快捷方式会失效。`Install-CodexHalo.cmd` 会按当前电脑的新路径重新生成：

- `启动 Codex Halo.lnk`
- `停止 Codex Halo.lnk`
- `移动 Codex Halo.lnk`

因此新电脑第一次使用时，请先运行安装脚本。

---

## 检测原理

Codex Halo 的状态检测不是通过 CPU 占用率，也不是单纯检查进程是否存在。

后台脚本会持续查找最近更新的 Codex session 文件：

```text
%USERPROFILE%\.codex\sessions\**\*.jsonl
```

然后读取追加的新事件，根据事件类型更新 Halo 状态：

| Codex session 事件 | Halo 状态 |
| --- | --- |
| `task_started` | `thinking` |
| `function_call` | `executing` |
| `function_call_output` | `thinking` |
| `task_complete` | `completed` |

状态会写入一个临时状态文件：

```text
%TEMP%\codex-halo-state2.txt
```

Halo 程序读取这个状态文件并更新颜色。

后台监控 PID 记录在：

```text
%TEMP%\codex-halo-monitor.pid
```

停止信号文件为：

```text
%TEMP%\codex-halo-stop.txt
```

---

## 为什么不用 CPU 或进程检测

曾经尝试过用 CPU 波动、`codex` 进程、`codex-command-runner` 进程判断状态，但实际使用中会有明显误判：

- 没有任务时，点击 Codex 界面也可能触发 CPU 波动；
- 只靠工具 runner 无法覆盖纯模型输出；
- 多个 Codex 窗口或后台进程会干扰判断；
- Windows 进程名大小写和启动方式也会带来不稳定性。

读取 session 事件更接近 Codex 的真实任务生命周期，因此当前版本采用这种方式。

---

## 隐私说明

Codex Halo 不包含上传逻辑，也不会主动访问网络。

它会读取本机 Codex session JSONL 文件中的事件行，用来识别 `task_started`、`function_call`、`task_complete` 等状态标记。

请注意：

- session 文件中可能包含你的 Codex 使用记录；
- Codex Halo 只在本机读取这些文件；
- 本项目不会把这些内容发送到任何地方；
- 如果你修改脚本或二次分发，请保留这一说明。

---

## 常见问题

### 双击“启动 Codex Halo”没有反应

优先检查是否是快捷方式路径失效：

1. 运行 `Install-CodexHalo.cmd`；
2. 再双击 `启动 Codex Halo`；
3. 如果仍然没有反应，直接双击 `_internal\codex-halo.exe` 测试光环程序是否能打开。

如果 `_internal\codex-halo.exe` 能打开，说明程序没问题，多半是快捷方式或 PowerShell 脚本问题。

### Windows 提示阻止运行

如果从网络下载 zip，Windows 可能会加上安全标记。

可以尝试：

1. 右键 `codex-halo.exe`；
2. 打开“属性”；
3. 如果看到“解除锁定”，勾选后确定；
4. 再重新启动。

也可能会出现 SmartScreen 提示，可以选择“更多信息”后继续运行。

### 光环一直灰色

灰色代表没有检测到新的 Codex 任务事件。

如果 Codex 明明在运行任务但 Halo 仍然灰色，可能原因包括：

- 当前 Codex 没有写入 session JSONL；
- session 路径不是默认的 `%USERPROFILE%\.codex\sessions`；
- Codex 更新后改变了日志格式；
- 后台监控脚本没有启动。

可以先双击 `停止 Codex Halo`，再双击 `启动 Codex Halo`。

### 复制到其他电脑后不能用

请先运行：

```text
Install-CodexHalo.cmd
```

不要直接使用从另一台电脑复制过来的旧 `.lnk` 快捷方式。

### 是否支持 macOS 或 Linux

当前版本只面向 Windows。

---

## 脚本说明

| 文件 | 作用 |
| --- | --- |
| `codex-halo.exe` | 桌面光环显示程序 |
| `Start-CodexHalo.ps1` | 启动 Halo，监听 Codex session 事件，恢复保存位置 |
| `Stop-CodexHalo.ps1` | 停止 Halo 和后台监控 |
| `Move-CodexHalo.ps1` | 打开移动界面，拖动并保存位置 |
| `Rebuild-Shortcuts.ps1` | 根据当前路径重建快捷方式 |
| `Rebuild-Shortcuts.cmd` | 用于双击调用重建脚本 |
| `Install-CodexHalo.cmd` | 新电脑首次使用入口，重建快捷方式 |
| `position.txt` | 保存光环坐标 |
| `halo-icon.svg` | 图标资源 |

---

## 开发说明

当前项目由两部分组成：

1. **光环显示程序**  
   `codex-halo.exe` 负责显示悬浮光环，并根据状态文件更新颜色。

2. **Windows 控制脚本**  
   PowerShell 脚本负责启动、停止、移动、读取 Codex session 事件、写入状态文件。

如果只是调整检测逻辑、启动方式、快捷方式或位置保存，通常只需要修改脚本，不需要重新编译 exe。

如果要调整光环动画、窗口行为、视觉效果或程序名称，则需要修改桌面程序源码并重新构建。

## 致谢

Codex Halo 的想法和 Windows 光环实现参考了：

[Houyusu/claude-halo](https://github.com/Houyusu/claude-halo)

原项目面向 Claude Code hooks。本项目将状态来源改为 Codex 本地 session 事件，并补充了适用于 Windows 桌面的启动、停止、移动、无终端后台运行和便携快捷方式重建脚本。

---

## 免责声明

Codex Halo 不是 OpenAI 官方项目，也不是 Codex 官方插件。

它只是一个本地桌面辅助工具。使用前请确认你理解它的工作方式：它会读取本机 Codex session 日志中的任务事件，用于显示桌面状态光环。
