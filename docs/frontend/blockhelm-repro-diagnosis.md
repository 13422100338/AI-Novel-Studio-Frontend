# BlockHelm 式 Windows 原生 Acrylic 复现——完整经历与诊断文档

> 目的：把“在 AI Novel Studio 正式前端复现 BlockHelm 窗口级毛玻璃效果”的
> 全部尝试、数据与失败点记录成文，供另一位 AI 直接接手诊断。
>
> 结论先行：**用户判定失败**。正式程序运行后背景板与 BlockHelm 效果
> “一点关系也没有”，截图可见背景板被应用内装饰层（自绘卡片/文字/光斑）
> 覆盖；且用户要求的是“背景板透出窗口后方程序（如微信聊天界面）的
> 轮廓”，当前实现无法稳定肉眼可辨地达成。

---

## 1. 环境与约束

| 项 | 值 |
| --- | --- |
| 项目 | AI Novel Studio **前端独立仓库**（不是 Electron） |
| 技术栈 | **PySide6 6.11.1 + QML**（Qt Quick，RHI） |
| 正式窗口 | `App.qml`（ApplicationWindow），WebEngine / TextArea 两种正文模式 |
| 实验窗口 | `NativeGlassLab.qml`（`--native-glass-lab` 独立入口） |
| 系统 | Windows 11 25H2 build 26200，透明效果开启 |
| 隔离约束 | 前端 Worktree（`C:\Users\钟子诚\.codex\worktrees\frontend-clean`），
  分支 `codex/frontend-agent-c1`，不碰后端/主 checkout |
| 参考项目 | `zqq-699/BlockHelm-Launcher`（WPF/.NET 8，GPL-3.0，用户已豁免复制限制） |

## 2. BlockHelm 实现要点（源码结论）

已克隆并阅读其源码（`C:\CodexTemp\blockhelm-e31f4c5e`）：

- **Acrylic Mode（DWM 路线）**——`Launcher.App/Services/Windowing/NativeBackdrop.cs`：
  - `DwmExtendFrameIntoClientArea(hwnd, MARGINS{-1,-1,-1,-1})`
  - `DwmSetWindowAttribute(UseImmersiveDarkMode=20, 1)`
  - `DwmSetWindowAttribute(WindowCornerPreference=33, Round=2)`
  - `DwmSetWindowAttribute(BorderColor=34, 0xFFFFFFFE)`
  - `DwmSetWindowAttribute(SystemBackdropType=38, TransientWindow=3)`（Desktop Acrylic）
  - WPF `Window.Background = Transparent` + `WindowChrome.GlassFrameThickness=-1`
- **Image Mode（应用内背景图路线）**——`ImageBackdropSource.cs` +
  `BackdropBlurBorder.cs`：一张背景图作为源，卡片用 VisualBrush 采样该图 +
  `BlurEffect`（低分辨率 BitmapCache 保性能）。轮廓清晰是因为模糊的是
  **应用自己的图**，与 DWM 无关。
- 设置模型：`LauncherBackgroundEffects` 三态 `None / Acrylic / Image`，
  运行时切换，关闭时 `DWMSBT_NONE` 并恢复不透明。

## 3. 我们复现了什么（提交时间线）

| commit | 内容 |
| --- | --- |
| `fba0c7e` | 独立 Native Glass Lab（DWM Acrylic/Mica、能力检测、回退、深浅主题） |
| `a343050` | 用“红/青 split 条纹窗 + 移动窗口”验证 DWM 采样后方；wash 0.30→0.15 |
| `58e4dce` | GlassLab 补 `DwmExtendFrameIntoClientArea(-1)` + DWM 日志 + 透明度滑块 |
| `6d915e7` | Lab `image` 模式（应用内背景图模糊，BlockHelm Image Mode QML 移植） |
| `745910c` | 聊天模拟窗口验证：DWM 透出后方色块（std 0→46）；对齐 corner/border 属性 |
| `cf74f21` | 正式 Shell 接入 DWM Acrylic（无边框 + 自绘标题栏 + wash 0.15） |
| `e99add1` | 正式 Shell 中央 workspace/WritingPage 透明化 |
| `145dc96` | 面板改为纯半透明 tint（`AcrylicSurface.nativeGlassActive`，关应用内 blur） |
| `8d08535` | 隐藏应用内装饰层 `BackdropLayer`（native 激活时） |

另有一个独立 WPF 演示（`C:\CodexTemp\blockhelm-demo-a7611937`，可运行，
截图见 `docs/frontend/screenshots/blockhelm-demo-*`），用户认可其
“半透明色块 + DWM 透出”效果，但认为正式程序没有复现。

## 4. 像素级证据（真实屏幕 `QScreen.grabWindow(0)`）

| 实验 | 指标 | 结果 |
| --- | --- | --- |
| Lab 标题栏背景条（纯色壁纸后方） | std | ≈0（纯色） |
| Lab 标题栏背景条（聊天模拟窗口后方） | std | 46.3，unique=173 |
| Lab 标题栏背景条（红/青 split 条纹后方，x=交界） | std | ≈99 |
| Lab 标题栏背景条（条纹后方，x=纯青区） | 颜色 | 纯青 (0,188,212) |
| 正式 Shell acrylic（Edge 聊天页后方） | 面板区 unique | 369（vs solid 2） |

结论：**DWM 确实在采样窗口后方内容**（移动窗口时颜色跟随），
“材质未生效”不是失败点。失败点在“用户肉眼看正式程序时没有玻璃感”。

## 5. 用户反馈与判定

1. “只在 dark 主题能看出来（很不明显），其他主题看不出来；只是颜色改变，
   没有映出其他程序或壁纸轮廓。”
2. “不是不明显，是根本看不出来。”
3. 看了 BlockHelm WPF 演示后：“这个效果就挺不错，干脆把我们程序的背景板
   都改成这样。”
4. 正式程序改完后：“背景板是和 lab 的 internal 模式一样的效果，没有达到
   BlockHelm 的效果。”
5. 再次修复后（隐藏装饰层）：“更失败了，背景板底部你自己画的不知道什么
   东西，跟 BlockHelm 的效果一点关系也没有。”

最终判定：**FAIL（按用户标准）**。

## 6. 疑点分析（请下一位 AI 重点排查）

### 6.1 Qt 透明窗口的 alpha 是否真的交给 DWM（最高优先级）

- `QQuickWindow.setDefaultAlphaBuffer(True)` 已在首个窗口创建前调用；
- `ApplicationWindow.color: "transparent"`（nativeActive 时）；
- 但 Qt 6.11 的 RHI 后端渲染出的表面，**alpha 通道在 DWM 合成时是否保留**
  未被直接证明。PrintWindow(PW_RENDERFULLCONTENT) 的证据可能是“材质 tint
  被合成”，不等于“窗口透明区域真透出后方”。建议直接：
  - 用 DWM 视角检查窗口格式（`GetWindowLong`/`DwmGetWindowAttribute`）；
  - 做一个“纯透明、无任何内容”的 Qt 窗口放条纹后方，验证屏幕合成；
  - 检查 `DWMWA_REDIRECTIONBITMAP_ALPHA=39` 是否真的必要且已生效。

### 6.2 用户看到的“自己画的东西”是否已彻底清除

- `8d08535` 在 `nativeGlassActive` 时隐藏 `BackdropLayer`，但用户反馈截图
  是在该 commit 之前还是之后不明。**请重新启动最新代码确认**，并检查
  `windowWash`（0.15 alpha bgCanvas）是否仍是“假背景”。
- 其余页面（记忆库/高级创作/设置）与 AgentDock 是否有未清除的不透明/装饰层，
  需逐面板截图核对。

### 6.3 面板“半透明 tint”是否真的透明

- `AcrylicSurface.nativeGlassFill` alpha=0.42，但 `fill` Rectangle 之后
  `luminosity`/`liquidLights`/`NoiseOverlay` 可能仍叠在面板上，形成
  “看似半透明实则带底色”的效果，与 BlockHelm 的纯 tint 不同。

### 6.4 DWM Acrylic 的“轮廓可见性”天花板

- Windows 11 Desktop Acrylic 模糊半径极大，后方文字/细节会被抹平，
  只能看到“色调跟随 + 大色块轮廓”。若用户要“微信聊天界面文字级轮廓”，
  单靠 DWM 做不到；BlockHelm 演示里可见的轮廓也主要来自其半透明卡片下的
  DWM 色块，而非清晰文字。需与用户对齐“可接受的效果下限”。

### 6.5 正式程序与 WPF 演示的差异

- WPF 演示窗口内容极简（几个半透明卡片），无内容/装饰层干扰；
- 正式程序有完整 UI（导航、侧栏、正文、状态栏、AgentDock），任何一处
  不透明/装饰都会破坏整体玻璃感。建议先做成“最小可对比形态”再叠加 UI。

## 7. 给下一位 AI 的诊断任务清单

1. 用最新代码（`8d08535`）启动正式程序，截图对比 BlockHelm 演示，
   确认装饰层是否真的没了。
2. 验证 Qt 透明窗口 alpha 在 DWM 合成中是否生效（6.1）。
3. 逐面板核对是否有残留不透明/装饰层（6.2/6.3）。
4. 与用户确认“轮廓”的可接受下限（6.4）。
5. 若 DWM 路线在 Qt 下无法达到目标，评估：
   - 应用内实时捕获窗口后方 + 模糊（曾实现 `WDA_EXCLUDEFROMCAPTURE`
     方案后回滚，见 git 历史 `live_backdrop` 相关删除）；
   - 或接受“DWM 色块轮廓”作为正式效果并弱化 UI 干扰。

## 8. 参考文件

- 正式窗口：`src/ai_novel_studio/ui_qml/qml/App.qml`
- 页面背景：`src/ai_novel_studio/ui_qml/qml/pages/WritingPage.qml`
- 玻璃面板：`src/ai_novel_studio/ui_qml/qml/surfaces/AcrylicSurface.qml`
- 应用内装饰层：`src/ai_novel_studio/ui_qml/qml/surfaces/BackdropLayer.qml`
- DWM 桥：`src/ai_novel_studio/ui_qml/bridge/windows_backdrop.py`
- 启动接线：`src/ai_novel_studio/ui_qml/bootstrap.py`
- Lab：`src/ai_novel_studio/ui_qml/qml/NativeGlassLab.qml`
- 证据截图：`docs/frontend/screenshots/glass-shell-*`、
  `blockhelm-demo-*`、`glass-lab-over-*`、`native-glass-lab-*`
- WPF 演示源码：`C:\CodexTemp\blockhelm-demo-a7611937`
- BlockHelm 源码：`C:\CodexTemp\blockhelm-e31f4c5e`
