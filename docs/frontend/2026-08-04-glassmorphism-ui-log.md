# AI Novel Studio 玻璃化 UI（Glassmorphism）思路与过程记录

> 分支：`codex/frontend-agent-c1`
> 状态：**未达成用户目标，已暂停（2026-08-04）**。实验页的“应用内实时
> Acrylic”已可用；但“底板透出桌面壁纸”的系统 Mica 路线在真机上仍
> 未达到预期视觉效果（详见 §5 诊断与 §7 遗留问题）。本文档是日后恢复
> 该方向时的完整思路记录。
> 工作树：`C:\Users\钟子诚\.codex\worktrees\frontend-clean`

## 1. 目标与约束

### 1.1 用户需求（按时间澄清后的最终版）

1. Visual V0 样板页的玻璃效果“一般般”，要求联网调研玻璃化（Glassmorphism）
   经验与技术后再返工；
2. 关键澄清：**底板（窗口底层）可以微微透出程序后面的图像（桌面壁纸）**；
3. 关键澄清：**各个面板要有玻璃质感，但不要透出程序后面的图像**；
4. 正式界面（App.qml / NavigationRail / CreativeAgentPanel 等）不得改动，
   只做 `--visual-lab` 独立实验页；
5. 质量档 Safe / Balanced / Premium 必须可回退（规范 11）；
6. 前后端保持隔离；改动只落在 frontend-clean worktree。

### 1.2 本轮可接受范围

- 实验页可引入系统级材质（Mica / Desktop Acrylic）评估方向；
- 正式 Shell 不做透明窗口 / 系统背板（WebEngine 风险，见 §7.3）；
- 所有高级效果失败时静默回退到普通主题色。

## 2. 联网调研结论（返工依据）

### 2.1 NNGroup《Glassmorphism: Definition and Best Practices》

- 玻璃态 = **不透明度 × 背景模糊**，两个特征缺一不可；
- 仅做半透明 + 边框 + 噪声、没有模糊，看起来只是普通半透明面板
  （这正是第一版 `GlassSurface`“一般般”的根因）；
- 模糊要足够强（约 25–100px），复杂背景上效果更明显；
- 文本必须满足对比度；可让用户调整透明度（对应 Safe/Balanced/Premium）。

### 2.2 Qt 官方博客《Qt Quick and Blurred Panels》

- 模糊的是**面板背后的内容**，不是面板本身；
- 简单场景：`ShaderEffectSource(sourceItem=背景层, sourceRect=面板区域)`
  + `MultiEffect(blurEnabled, autoPaddingEnabled:false, blurMax)`；
- 高级场景：`maskEnabled/maskSource`（layer 化圆角矩形）实现非矩形模糊；
- 性能：模糊像素越少越好；`autoPaddingEnabled:false` 防止效果跑出窗口。

### 2.3 PyHuskarUI `HusAcrylic.qml`（Fluent Acrylic 分层）

- 顺序：捕获背后 → `MultiEffect blurMax≈32` → 亮度层（luminosity）
  → 色调层（tint，opacity≈0.65）→ 平铺噪声 PNG（opacity≈0.02）；
- `sourceRect` 必须按组件在源层坐标系中的位置映射。

### 2.4 Qt MultiEffect 文档

- `blur: 0..1`，`blurMax` 有效 2–64（默认 32）；`saturation/brightness`
  为 0 时无变化；
- `maskSource` 可指向 `layer.enabled` 的 Item；
- 性能：blur/shadow 最重；不在动画中改 `blurMax`/`autoPaddingEnabled`；
  空闲时关闭效果（`enabled:false`）；
- 离屏 software 后端也能渲染 MultiEffect（本机 Qt 6.11.1 已验证）。

### 2.5 微软 DWM 系统背板（透壁纸的关键 API）

- `DwmSetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE=38)`；
- `DWMSBT_MAINWINDOW (2)` = Mica（整窗后壁纸模糊采样，材质低调）；
- `DWMSBT_TRANSIENTWINDOW (3)` = Desktop Acrylic（更亮）；
- `DWMSBT_TABBEDWINDOW (4)` = Mica Alt；
- `DWMSBT_NONE (1)` = 关闭；
- 要求 Windows 11 build 22621+；此前需用未公开的 `DWMWA_MICA_EFFECT`。

### 2.6 社区线索（部分未验证）

- win32mica：Win32 应用透明背景要求“extended composition”，Mica 行为不保证；
- AutoHotkey / MicaForEveryone 线索：窗口**保持不透明**、背景纯黑时，
  DWM 会用 Mica 替换黑色像素——“不透明窗口 + 纯黑背景”是一条备选路径；
- Qt 论坛：QML 透明窗口 + Mica 有白块、resize 后才透明等怪癖
  （“phantom white box”、6.10/6.11 均有报告）。

## 3. 两条技术路线

| 路线 | 原理 | 现状 |
| --- | --- | --- |
| A. 应用内实时 Acrylic | `ShaderEffectSource` 捕获应用内背景层 → `MultiEffect` 模糊 | **可用**（实验页） |
| B. 系统级 Mica / Desktop Acrylic | DWM 在窗口后面绘制壁纸模糊 | DWM 调用成功，**视觉未通过** |

最终用户目标对应 **B（底板透壁纸）+ A 的“面板玻璃质感但绝不出壁纸”**
组合：B 只在窗口底板层生效，面板使用不透明的玻璃装饰（实色底 + 高光 +
细边 + 噪声）。

## 4. 实现历程（按提交）

### 4.1 `0247556` — Visual V0 玻璃返工（实时 Acrylic 实验）

- 新增 `qml/surfaces/AcrylicSurface.qml`：
  - `sourceItem`（必填）= 被模糊的背景层，调用方保证不含面板本身，
    杜绝自捕获递归；
  - `ShaderEffectSource(sourceRect=mapToItem 结果, enabled=effectActive)`
    + `MultiEffect(blurMax 24/40, mask 圆角, autoPaddingEnabled:false)`
    → 亮度层 → 色调层（tint 0.62）→ 高光/深边 → `NoiseOverlay`；
  - Safe 档完全实色（无 Shader、无 MultiEffect）；
  - 性能门禁：`visible=false` 或 Safe 时 `capture.enabled=false`。
- `VisualLab.qml`：新增 `labBackgroundLayer`（渐变 + 格线 + 低饱和色块 +
  手稿卡 + 大纲卡），AI 主面板与材质对比行改用 Acrylic；
- tokens：`acrylicTint`、`glassBlurBalanced(24)`、`glassBlurPremium(40)`、
  `glassTintOpacity(0.62)` 等。

### 4.2 `5091910` — 修复背景黑块（QML 类型坑）

- 现象：底板“一块白一块黑”；
- 根因：`tint()` 辅助函数参数未声明类型，`Theme.tokens.*` 是字符串，
  `Qt.rgba(undefined,...)` 静默输出黑色；
- 修复：参数声明为 `color` / `real`，中间渐变档也走同一函数。

### 4.3 `710e13d` — Mica 系统背板（透壁纸方向）

- 新增 `bridge/windows_backdrop.py`：`DwmSetWindowAttribute(38, Mica=2)`，
  Win11 22621+ 才生效，失败静默 False；
- `bootstrap.py --visual-lab` 启动时应用并把结果写入 `systemBackdrop`；
- `GlassSurface.qml` 新增 `opaque` 属性（实色底 + 玻璃装饰，不透壁纸）；
- `VisualLab.qml`：Mica 模式下窗口透明 + 主题洗白层 + 隐藏应用内装饰
  背景；AI 面板切 `GlassSurface.opaque`；对比行显示 Mica 底板；
- 截图脚本新增 `--windowed`（真机截图）。

### 4.4 `af7e2a8` — 质量档在 Mica 模式下可区分

- 用户反馈“三档看不出区别”（原因：三档当时渲染成同一块不透明玻璃）；
- Safe = `DWMSBT_NONE` + 不透明窗口；Balanced = Mica；Premium =
  Desktop Acrylic；
- `theme.quality_changed` → Python 重新下发对应 DWM 背板；
- 顶栏新增「系统背板」状态芯片（Safe 关闭 / Mica / Desktop Acrylic）。

### 4.5 `f0c6dfa` — 调薄洗白层（当前 HEAD）

- 用户反馈“一团灰，档位间只是灰色深浅不同，透不出壁纸”；
- 真机诊断（见 §5）证明 DWM 调用成功、窗口非 layered，灰色来自我们
  自己的 0.8 不透明度主题洗白层；
- 修复：洗白层 Balanced `0.80 → 0.32`、Premium `0.66 → 0.18`；
- 当前状态：**该修复尚未经用户真机确认，用户选择暂停玻璃化方向**。

## 5. 失败诊断（重要证据，2026-08-04 真机）

复现命令：`scripts\diagnose_windows_backdrop.py`（已入库，真机运行）。

探针结果：

```text
wallpaper path: C:\Users\钟子诚\AppData\Local\Packages\MicrosoftWindows.
Client.CBS_cw5n1h2txyewy\LocalCache\Microsoft\IrisService\
4702723315681337929\134301076053937913.jpg   <- Windows 聚焦多彩风景图
WS_EX_LAYERED: False 0x100                    <- Qt 透明窗口未被设成 layered
DwmSetWindowAttribute(Mica) hr: 0x0 S_OK      <- DWM 系统背板调用成功
SetWindowCompositionAttribute(AcrylicBlurBehind): 0 FAILED  <- 旧 API 不可用
```

结论：

- “没接上”不成立：DWM 调用返回 S_OK，且窗口不是 layered（不存在常见冲突）；
- 当时看到“一团灰”的直接原因是 **0.8 不透明度主题洗白层把 DWM 背板
  完全盖住**（Safe 档没有该层所以正常）；
- 洗白层已调薄（0.32 / 0.18），但用户尚未验证；此外 Mica 材质本身
  偏低调，调薄后可能仍不够“毛玻璃感”。

## 6. 当前代码结构

```text
src/ai_novel_studio/ui_qml/
  bridge/windows_backdrop.py        # DWM 系统背板封装 + 质量档→类型映射
  bootstrap.py                      # --visual-lab 接线；quality_changed→DWM
  qml/surfaces/AcrylicSurface.qml   # 应用内实时 Acrylic（路线 A）
  qml/surfaces/GlassSurface.qml     # opaque 属性（不透壁纸的玻璃装饰）
  qml/VisualLab.qml                 # backgroundLayer / micaActive / wash / 状态芯片
tests/ui_qml/
  test_visual_lab.py                # Mica 三档断言、captureRect、opaque 切换
  test_windows_backdrop.py          # DWM 常量与失败安全
scripts/
  diagnose_windows_backdrop.py      # 真机诊断探针（本次入库）
  capture_frontend_visual_lab.py    # --windowed 真机截图
docs/frontend/
  2026-08-04-frontend-visual-v0-glass-rework.md   # 交付记录
  2026-08-04-glassmorphism-ui-log.md              # 本文档
```

关键 QML 决策：

- `micaActive = systemBackdrop && Theme.visualQuality !== "safe"`：
  Safe 永远不透壁纸（规范 11 实色背景）；
- 窗口透明只在 Mica 生效时开启：`color: micaActive ? "transparent" :
  Theme.tokens.color.bgCanvas`；
- 洗白层（可读性层）只覆盖底板，不覆盖面板。

## 7. 遗留问题与未来方向（恢复点）

### 7.1 待用户真机确认

```powershell
cd C:\Users\钟子诚\.codex\worktrees\frontend-clean
.\.venv\Scripts\python.exe -m ai_novel_studio.ui_qml --visual-lab
# 或真机截图：
.\.venv\Scripts\python.exe scripts\capture_frontend_visual_lab.py --windowed
```

确认点：

1. 洗白层 0.32 / 0.18 后，Balanced / Premium 是否能看到壁纸模糊色彩透出；
2. 顶栏状态芯片是否显示 Mica / Desktop Acrylic（确认 DWM 生效）；
3. 面板是否保持“有玻璃质感但看不到壁纸内容”。

### 7.2 若仍无法透出壁纸：候选方案（按优先级）

1. **不透明窗口 + 纯黑背景（DWM 替换）**：窗口不透明、背景色纯黑，
  由 DWM 用 Mica 替换黑色像素（AutoHotkey / MicaForEveryone 路径）。
  最接近 Win32 语义，需实验 Qt 黑色像素是否被替换；
2. **Qt 层自绘壁纸模糊**：读取壁纸文件（`SPI_GETDESKWALLPAPER`）或截取
  屏幕 → 缩放 + `MultiEffect` 模糊 → 作为窗口背景层。100% 可控、不依赖
  DWM 合成，可作为 Premium 备选（注意壁纸换用/多显示器/性能）；
3. **DComp / CompositionTarget 系统背板**（`Window::set_dcomp_backdrop`
  等价物）：更底层、工作量更大，最后考虑；
4. **放弃系统透壁纸**：只保留应用内实时 Acrylic（路线 A，已可用），
  面板玻璃质感 + 应用内复杂背景。

### 7.3 正式 Shell 接入注意事项（未来如果要做）

- WebEngine 透明窗口风险高（黑底 / 合成异常 / 输入问题），规范 9.3 禁止
  对 WebEngineView 施加实时 Blur/大面积 MultiEffect；
- 必须提供一键回退（`--no-backdrop` 或设置项），失败自动回退普通主题色；
- 性能门禁：窗口 1080×680 起、缩放 100/125/150%、AI Dock 开关不重绘
  WebEngine、空闲特效停止渲染；
- 规范 12：Mica 只作用于窗口底层；Windows 10 / 调用失败时用普通 Canvas；
- 不为 Mica 改无边框窗口；不破坏 Snap / 最大化 / DPI / 标题栏行为。

## 8. 验证与复现命令速查

```powershell
cd C:\Users\钟子诚\.codex\worktrees\frontend-clean
$env:PYTHONPATH='src'; $env:QT_QPA_PLATFORM='offscreen'; $env:QT_QUICK_BACKEND='software'
.\.venv\Scripts\python.exe -m pytest tests/ui_qml -q --basetemp .test-temp/pytest-base
.\.venv\Scripts\python.exe -m ruff check src tests scripts
$env:MYPYPATH='src'; .\.venv\Scripts\python.exe -m mypy
# 集成（只读桥接）
$tmp=Join-Path $env:TEMP 'frontend-integration-bridge'
$env:PYTHONPATH="$tmp;C:\Users\钟子诚\.codex\worktrees\frontend-clean\src"
& 'C:\Users\钟子诚\.codex\worktrees\c9a2\AI-Novel-Studio\.venv\Scripts\python.exe' -m pytest tests/ui_qml -q
# 真机诊断 / 实验页 / 真机截图
.\.venv\Scripts\python.exe scripts\diagnose_windows_backdrop.py
.\.venv\Scripts\python.exe -m ai_novel_studio.ui_qml --visual-lab
.\.venv\Scripts\python.exe scripts\capture_frontend_visual_lab.py --windowed
```

最近一次验证基线：前端 pytest 154 passed / 35 skipped，c9a2 集成
230 passed，ruff / mypy 通过（均在 `f0c6dfa`）。

## 9. 一句话总结

应用内 Acrylic（模糊面板背后的应用内容）已实现并验证；系统级 Mica
（窗口后面透壁纸）的 DWM 调用本身成功，但视觉受洗白层掩盖影响，调薄后
尚未确认，方向暂缓。恢复时从 §7 开始：先真机看 `f0c6dfa` 效果，不行再按
§7.2 的候选方案（首选“不透明窗口 + 纯黑背景”）。
