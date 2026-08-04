# Frontend Visual V0：独立视觉样板页

> 分支：`codex/frontend-agent-c1`（独立提交，未合并 `main`）
> 依据：《AI_Novel_Studio_理想UI方向与现有架构渐进式实现规范》第 15 节 Visual V0
> 性质：**独立样板页，不修改正式界面**；由用户确认后再进入 Visual V1 全局替换。

## 1. 启动方式

```powershell
cd C:\Users\钟子诚\.codex\worktrees\frontend-clean
.\.venv\Scripts\python.exe -m ai_novel_studio.ui_qml --visual-lab
```

顶栏可实时切换主题（paper/light/dark）与质量档（Safe/Balanced/Premium）。
正式入口 `-m ai_novel_studio.ui_qml`（默认 WebEngine）完全不受影响。

## 2. 本轮交付

### Design Tokens 扩展（`bridge/theme_provider.py`）

- `material`：`glassFill`（#AARRGGBB 半透明）、`glassFillStrong`、`glassBorderHighlight`、
  `glassBorderShadow`、`paperFill`、`noiseOpacity`——按三主题分别取值；
- `elevation`：`shadowSoft` / `shadowStrong`（静态阴影，无实时模糊）；
- `motion`：`micro=100`、`normal=160`、`panelFade=140`、`glowCycle=2800`；
- `agent`：Thinking 蓝紫、Generating 蓝紫+暖金、Success/Error/Waiting/Cancelled；
- `Theme.visualQuality`（safe/balanced/premium）+ `setVisualQuality` / `nextVisualQuality`，
  无效值回退 Balanced（规范 11：效果失败自动回退）。

### 表面组件（`qml/surfaces/`）

- `GlassSurface.qml`：模拟玻璃——半透明底色 + 顶部内高光 + 细边框 + 底部深边 +
  低透明噪声 + 静态阴影；Safe 档自动退化为不透明表面；
- `PaperSurface.qml`：暖白不透明纸张 + 极轻噪声 + 柔和静态阴影（正文永不透明）；
- `FlatSurface.qml` / `ElevatedSurface.qml`：实色基础表面与静态抬升表面。

### 效果组件（`qml/effects/`）

- `NoiseOverlay.qml`：Canvas 一次绘制的静态噪点（Safe 隐藏）；
- `StaticGlowBorder.qml`：静态高亮边框（Balanced 档/降级态）；
- `StreamingGlowBorder.qml`：2.8s 慢速 A→B→A 边框色漂移、1.5px、
  仅当前活动卡；success/error/cancelled 定格状态色；`reduceMotion` 退化为静态高亮。

### 样板页（`qml/VisualLab.qml` + `--visual-lab` 入口）

三列布局：AI 玻璃表面（状态 chip、流光活动卡、按钮 Flow、输入框）/
正文纸张 + 按钮层级（primary/secondary/ghost/selected/disabled）/ Agent 结构化卡片
（TextDiffCard、ChangeSetCard、FormCard + StaticGlowBorder）。
`AppButton` 新增 `ghost` 层级（透明底 + accent 文字，hover 浅底）。

## 3. 六个 design/animation skill 的应用（本轮增量）

- **animation-vocabulary**：stagger（三列 50ms 级联入场）、fade、glowCycle、
  reduced motion；
- **apple-design**：入场只动 opacity（GPU 友好、不打断布局）；样板页为 Occasional
  频率 → 允许克制的 160ms 淡入；`reduceMotion` 全程 0ms；
- **emil-design-eng**：所有动画 ≤ 300ms（流光 2.8s 属 ambient 慢速，且仅限活动卡）；
  无 ease-in、无 scale(0)；按钮按压沿用 0.97/120ms；
- **find-animation-opportunities**：只对三列入场加 50ms stagger；拒绝为按钮、
  状态 chip 等高频元素添加多余动效；
- **improve-animations / review-animations**：流光实现走 ColorAnimation 可打断；
  Safe 档直接移除噪声/玻璃/流光，符合「效果失败自动回退」；评审结论 Approve。

## 4. 验证

```text
pytest（独立前端）   145 passed, 35 skipped
pytest（c9a2 集成）  221 passed, 0 skipped
ruff / mypy          通过
```

新增 `tests/ui_qml/test_visual_lab.py`：样板页组件齐全性、主题切换、
Safe→不透明降级、reduceMotion→流光静态化、质量档循环与无效值回退。

## 5. 截图（`docs/frontend/screenshots/`）

- `visual-lab-paper-balanced.png`（默认：玻璃 AI 面板 + 纸张 + 流光）
- `visual-lab-paper-safe.png`（Safe：全部降级为不透明表面）
- `visual-lab-dark-premium.png`（深色 + 玻璃 + 噪声）
- `visual-lab-light-safe.png`（浅色 + 实色）

## 6. 下一步（待用户确认）

- 若认可方向 → Visual V1 静态材质统一（导航轨、章节栏、正文纸张、AI 面板、
  输入框、按钮、重点 Agent 卡片），仍不做 Shader；
- 若需调整 → 在本样板页迭代（玻璃透明度、圆角、噪声强度、流光周期等），
  确认前不触碰正式界面。

## 7. 已知边界

- 无实时背景模糊（规范禁止）；Mica 属 Visual V4；
- 流光 border 为 QML 动画实现，非 Shader；V3 再评估 `streaming_border.frag`；
- `--visual-lab` 进程设置 `QT_QUICK_CONTROLS_STYLE=Basic` 以便 TextField
  `background` 生效，正式入口不改变样式。
