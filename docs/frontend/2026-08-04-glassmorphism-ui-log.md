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

## 10. 追加（2026-08-04）：路线纠偏已确认

用户提供《AI_Novel_Studio_玻璃化UI路线纠偏与后续实施任务》，正式采纳：

- **主路线**：不透明 Qt 窗口 + 应用内 `BackdropLayer` + 应用内
  `AcrylicSurface` 面板 + 不透明 `PaperSurface` 正文；
- **系统 Mica / Desktop Acrylic**：降级为可选实验，不再作为 Premium 核心
  或正式 Shell 依赖；`windows_backdrop.py` / 诊断脚本 / 洗白层调参保留；
- 质量档 Safe / Balanced / Premium 共享同一窗口合成模式与组件结构，
  只改变模糊、Noise、阴影、动效强度；
- 本轮已执行的最小动作：新增独立 `BackdropLayer.qml`（VisualLab 背景层
  提炼）、VisualLab 标注“主路线：应用内 Acrylic；Mica：可选实验”、纠偏
  文档入库 `docs/frontend/2026-08-04-glass-ui-course-correction.md`；
- 正式 Shell / 后端 / WebEngine 全部未改动；完整恢复顺序见纠偏文档 §11。

## 11. 追加（2026-08-04）：Visual V0 应用内 Acrylic 重做完成

按《Visual V0 实验页问题诊断与下一版重做要求》重做实验页（交付报告：
`docs/frontend/2026-08-04-visual-v0-app-acrylic-rework.md`）：

- VisualLab 从“组件陈列室”改为**四栏产品布局**：导航轨 / 章节栏 /
  正文 PaperSurface / AI Acrylic 面板（纯 QML 静态数据）；
- **不透明窗口**为主路线：BackdropLayer 覆盖全窗口 + 实色回退，杜绝
  黑色裸露区；自动断言全窗口覆盖与无纯黑像素；
- 调试控件移入 `ExperimentControlPanel`（右侧抽屉）；系统 Mica 降为
  默认关闭的实验开关，通过 `BackdropBridge.apply()` 按需启用；
- 质量档 Safe/Balanced/Premium 共享同一布局，仅改变 Blur/Noise/阴影强度；
- 自动测试：157 passed / 35 skipped；截图脚本输出
  `visual-v0-rework-*.png` 六张并自动断言。

## 12. 追加（2026-08-04）：iOS 26 Liquid Glass 层叠调研与实验页实装

用户提问：能否做到 iOS 最新版（Liquid Glass）的玻璃效果；现有 Premium 在
dark 下明显、light 下几乎看不出。本轮结论：**视觉近似可行，完全复刻不现实**。

### 12.1 调研结论（网上指导汇总）

- Apple HIG Materials：Liquid Glass 是动态材质，须克制使用、不要用在内容层；
  背景较亮时可叠 35% 黑色 dim 层保证可读性。
- UIKit（iOS 26）：`UIGlassEffect`（tintColor、isInteractive）+
  `UIGlassContainerEffect` 的 spacing 让相邻玻璃元素融合（Qt 无直接等价）。
- SwiftUI：`.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))`，
  需 iOS 26 gating + 非玻璃回退。
- Flutter `cupertino_liquid_glass` 0.6.x：blur ≈ 40、tint ≈ 0.3；
  **specular 斜向高光、edge lighting、inner shadow、noise grain、vibrancy
  boost**；light = matte & bright，dark = deep & contrasty。
- Floatica / DeepWiki：saturate(180%) 即约 +80% 饱和增强；多层 specular 与
  shape-aware edge glow 是 Liquid Glass 与普通毛玻璃的关键区别。

### 12.2 现有实现缺的四层（light 下看不出的根因）

1. 无斜向 specular 高光（"sheen"）——液态感的核心；
2. 无顶/左边缘光与底/右内阴影——厚度感；
3. light 主题饱和度为负（-0.1）——把背景颜色洗掉；
4. 浅色背景自身过白，blur+tint 没有颜色可透。

### 12.3 本轮改动（仅实验页 VisualLab / AcrylicSurface / 主题 token）

- `AcrylicSurface.qml`：新增单个静态 Canvas 一次绘制五层
  （斜向 specular、顶/左边缘光、底/右内阴影），用既有圆角 mask 裁切；
  Safe 档全隐藏，Balanced/Premium 强度由 token 控制（Premium 严格更强）。
- `theme_provider.py`：新增 `glassSpecular*` / `glassEdgeLight*` /
  `glassInnerShadow*` token；light 饱和度改为 +0.40、玻璃色调改为冷白
  `#F5F8FB`、Premium 透明度调回 0.52；背景光晕强度 token 化
  （`backdropGlowWarm/Cool`），light 调强（0.22/0.19）让 blur 有颜色可透。
- 验证：前端 pytest 165 passed / 35 skipped；ruff 通过；mypy（项目配置）
  通过；截图脚本新增 light 两档并增加 resize 后有界等待。

### 12.4 像素验证摘要（真机 windowed 截图）

- dark premium：面板顶缘亮度 83 vs 面板本体 41（+40），specular 上区 59 vs
  下区 43——边缘光与高光清晰可见。
- light premium：面板上部 ~230（偏冷蓝）vs 纸张 252，面板与纸张明显分离；
  premium 与 balanced 仅玻璃区有差异（avg diff 2.39，纸张区 0.0）。

### 12.5 已知限制与后续

- 无法复刻：多玻璃容器融合（UIGlassContainerEffect）、交互折射/形态变化、
  Fresnel rim 等，需要自定义 shader 或 WebEngine 的 WebGPU/CSS 路径，本轮不做。
- 正式 Shell / 后端 / WebEngine 未改动；方向确认后再考虑从
  `AcrylicSurface` 平移到正式 UI。
- light 下玻璃的“明显程度”由背景丰富度决定，token（specular/edge/glow）
  都可单独微调，不需要逐个按钮改魔法数字。

## 13. 追加（2026-08-04）：LiquidLights 抽取、卡片共享材质、扁平化收束

用户反馈第二轮：dark 斜向高光过于明显生硬、paper/light 又不够明显；既然
做了边缘光/内阴影，其他框（卡片）也该统一。第三轮追加：阴影整体要很微弱，
样式更趋于扁平化。

### 13.1 结构改动

- 新增共享组件 `surfaces/LiquidLights.qml`：一个静态 Canvas 一次绘制
  斜向 specular + 顶/左边缘光 + 底/右内阴影，自带圆角 clip（Canvas 2D
  roundedRect path + ctx.clip），替代原来 AcrylicSurface 内联的
  Canvas + MultiEffect mask 组合。
  - specular 渐变端点延伸到 `(w*1.15, h*0.75)`、亮带停靠拉宽，斜向光带
    变得宽而柔，不再是一条硬斜线。
- `AcrylicSurface.qml` 改挂 `LiquidLights`（radius/specular/edge/inner 全部
  由 token 驱动），面板外投影从 5px/3px 降到 3px/2px（扁平化）。
- `AgentCard.qml` 挂载淡 `LiquidLights`：卡片共享“光从左上落”的材质语言，
  只用边缘光 + 内阴影（specular 保持 0，不往内容上画高光）；Safe 档隐藏。
  三张实验卡片（TextDiff/ChangeSet/Form）与正式 CreativeAgentPanel 共用
  同一容器，一处改动全部生效。

### 13.2 强度收束（token，三主题）

- dark specular premium 0.26 → 0.16（柔和化）；paper 0.30 → 0.42、
  light 0.52 → 0.62（浅色下更明显，配合亮带拉宽）。
- glass 内阴影 premium 0.28/0.36/0.32 → 0.14/0.16/0.15；边缘光同步下调。
- 卡片内阴影 0.07/0.12/0.07 → 0.04/0.05/0.04，边缘光 0.14/0.12/0.16 →
  0.09/0.08/0.10——只保留极淡层次，扁平化。

### 13.3 验证

- 前端 pytest 166 passed / 35 skipped（新增卡片共享材质测试）；ruff 通过；
  mypy（项目配置）通过。
- 真机 windowed 像素：light/dark 面板底部内阴影亮度差收敛到 ~8-10/255
  （此前层级明显更深）；卡片内阴影 ~0.04-0.05，肉眼为极淡层次。

## 14. 追加（2026-08-04）：删除斜向高光、三栏边缘统一、背景光为光源

用户反馈第四轮：
1. 三个主窗口（导航轨 / 章节侧栏 / AI 面板）边缘设计不统一——有的有阴影、
   有的没有；
2. 斜向高光不要再加了；
3. 玻璃的光改为来自背景板（BackdropLayer）的背景光。

### 14.1 结构改动

- `LiquidLights.qml`：删除 `specularOpacity` 属性与斜向高光绘制逻辑，组件只
  保留顶/左边缘光 + 底/右内阴影，自绘圆角 clip 不变。注释明确：光来自
  BackdropLayer 背景光晕，不在面板表面画高光。
- `AcrylicSurface.qml`：删除 `elevated` 属性与外投影 Rectangle——三个玻璃
  面板统一为 1px 边框 + LiquidLights 边缘光/内阴影，不再出现"有的面板带投影、
  有的没有"；删除 specular 绑定。
- `VisualLab.qml`：移除导航轨/章节侧栏的 `elevated: false`（属性已删除）。
- `theme_provider.py`：移除 `glassSpecular*` token；paper/light 背景光晕
  增强（0.14/0.12、0.28/0.24）补偿浅色下失去 specular 后的可读性。

### 14.2 验证

- 前端 pytest 167 passed / 35 skipped（新增"三栏统一边缘材质"测试：断言
  共享表面无 `elevated` 开关、三栏 LiquidLights 强度一致）；ruff / mypy 通过。
- 真机 windowed 像素：AI 面板左上与右上亮度相近（light 220/225、dark 42/46），
  斜向高光消失；顶部边缘光保留（dark 71.8 vs 底部 47.6）；面板右侧外沿无
  阴影渐变，外投影已彻底移除。

## 15. 追加（2026-08-04）：中央正文工作区统一为玻璃样式

用户反馈第五轮：最中间的文本框（正文工作区）也应该改成相同的玻璃样式。

### 15.1 改动

- `VisualLab.qml`：中央正文从不透明 `PaperSurface` 换成 `AcrylicSurface`
  （objectName 保留 `labPaperSurface`），`sourceItem: backgroundLayer`、
  `radius: r12`，与 AI 面板一致；内部章节标题/正文段落/状态行布局不变。
  Safe 档自动回退为不透明 `bgSurface`（AcrylicSurface 既有行为）。
- `test_visual_lab.py`：统一材质测试从三栏扩展为四面板
  （`test_four_main_panels_share_unified_edge_material`），断言正文面板
  `elevated` 不存在、LiquidLights 强度与 AI 面板一致、`sourceItem` 为
  `labBackgroundLayer`。

### 15.2 验证

- 前端 pytest 167 passed / 35 skipped；ruff 通过；mypy（项目配置）通过。
- 真机 windowed 像素：正文顶部边缘光与 AI 面板一致（dark 72.8 vs 71.2、
  light 246.7 vs 240.9），正文区域呈现玻璃质感（dark body 56、light 230，
  半透明透出背景冷调光晕）。
