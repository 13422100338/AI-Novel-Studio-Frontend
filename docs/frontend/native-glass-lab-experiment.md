# Native Glass Lab（原生毛玻璃测试界面）

> 分支：`codex/frontend-agent-c1`
> 工作树：`C:\Users\钟子诚\.codex\worktrees\frontend-clean`
> 依据任务文档：《AI-Novel-Studio-原生毛玻璃测试界面-实施任务.md》（Electron 版）
> 状态：独立隔离实验，不接正式 Shell，不碰后端。

## 1. 文档审计结论

原实施文档的方向与验收标准成立，但技术栈写的是 Electron + React，本项目是
PySide6 6.11 + QML，因此按等价能力做了映射：

| 原文档（Electron） | 本项目等价实现 |
| --- | --- |
| `BrowserWindow` + `backgroundMaterial: "acrylic"` | `QQuickWindow` + `DwmSetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE=3)`（ctypes） |
| React 根节点透明（`html/body/#root` 透明） | `ApplicationWindow.color: "transparent"` + `QQuickWindow.setDefaultAlphaBuffer(true)` |
| `win.setBackgroundMaterial("acrylic")` 动态切换 | `NativeGlassBridge.apply(kind)`（DWM 属性可运行时切换） |
| `contextIsolation/preload` 安全边界 | 能力检测与 DWM 调用集中在 `windows_backdrop.py`，QML 只读状态 |
| 平台/版本降级 | `windows_build()` / `transparency_effects_enabled()` 检测，失败回退 `internal` / `solid` |

关键纠偏（调研结论）：

- **Mica 永远不透出窗口后方内容**：`DWMSBT_MAINWINDOW(2)` 只采样壁纸与主题色，
  是类不透明材质；要验证“透出并模糊窗口后方画面”，必须使用
  **Desktop Acrylic（`DWMSBT_TRANSIENTWINDOW=3`）**。
- 此前 Visual V0 的 Mica 实验只看到灰色，根因是 QML 洗白层盖住了 DWM 材质 +
  系统“透明效果”未确认开启；DWM 调用 `S_OK` 不等于最终像素生效。
- Qt 透明窗口需要：`FramelessWindowHint` + `setDefaultAlphaBuffer(true)`（首个窗口
  创建前）+ `color: "transparent"`；`DwmSetWindowAttribute` 在 `winId()` 之后调用，
  show 后需重新应用一次（首次显示竞态）。

## 2. 新增/改动文件

- `src/ai_novel_studio/ui_qml/qml/NativeGlassLab.qml`（新增）：独立无边框实验页
- `src/ai_novel_studio/ui_qml/bridge/windows_backdrop.py`：能力检测、透明效果检测、
  Desktop Acrylic / Mica / 动态切换、immersive dark mode、redirection-bitmap alpha
- `src/ai_novel_studio/ui_qml/bootstrap.py`：`NativeGlassBridge` + `--native-glass-lab` 入口
- `src/ai_novel_studio/ui_qml/qml/surfaces/AcrylicSurface.qml`：`opaqueFallback`（solid 模式）
- `tests/ui_qml/test_native_glass_lab.py`（新增，子代理）
- `tests/ui_qml/test_native_glass_bridge.py`（新增）：真实 `NativeGlassBridge`
  状态机单元测试（成功/失败/清除/refresh/门控，12 个）
- `scripts/capture_native_glass_lab.py`（新增）：离屏/真机截图，`PrintWindow`
  合成证据；支持将 Lab 置顶到条纹窗之上（`--windowed` 时自动 `_make_topmost`）
- `scripts/stripe_backdrop_window.py`（新增）：全屏高对比彩色条纹背景窗，
  用于“DWM 是否真的模糊窗口后方内容”的决定性对照实验

## 3. 运行方式

```powershell
.\\.venv\\Scripts\\python.exe -m ai_novel_studio.ui_qml --native-glass-lab
```

页面顶部按钮：

- `native` / `internal` / `solid`：切换真实 DWM 材质 / 应用内 Acrylic / 纯色
- `Desktop Acrylic` / `Mica`：原生材质二选一（默认 Acrylic）
- 深色 / 浅色：主题切换（同时切换 DWM immersive dark mode）
- 自定义标题栏：拖动窗口、最小化、最大化、关闭

决定性对照实验（条纹窗 + 真机截图）：

```powershell
# 1) 先启动条纹背景窗（默认 120s，可加 --seconds 600 延长）
.\\.venv\\Scripts\\python.exe scripts\\stripe_backdrop_window.py --seconds 600
# 2) 再跑 windowed 截图（Lab 会自动置顶到条纹窗之上）
.\\.venv\\Scripts\\python.exe scripts\\capture_native_glass_lab.py --windowed
```

## 4. 验收与验证

已验证（2026-08-06，本机 Windows 11 25H2 build 26200，透明效果开）：

- `pytest tests/ui_qml -q --basetemp .pytest-tmp`：210 passed / 35 skipped
  （含新增 `test_native_glass_lab.py` 10 个测试：加载、默认状态、模式切换、
  DWM 成功/失败回退、mica 切换、主题切换、四面板几何、正文长度、状态栏贴底；
  以及 `test_native_glass_bridge.py` 12 个真实桥状态机测试）。
- `ruff check`：全部通过；`mypy`（`MYPYPATH=src`）：42 文件无问题。
- 离屏截图：`scripts/capture_native_glass_lab.py` 输出 6 张状态图并通过
  “无纯黑块”断言。
- 真机 windowed 截图：`--windowed` 输出应用内容图 + `PrintWindow` 合成证据图
  （`native-glass-lab-*-composed.png`）。`QScreen.grabWindow(0)` 在本机无法
  抓取无边框透明窗口（实测被前台游戏画面覆盖），因此 DWM 合成证据以
  `PrintWindow(PW_RENDERFULLCONTENT)` 为准。
- 修复记录：`DWMWA_REDIRECTIONBITMAP_ALPHA` 常量从 30 修正为 39（Windows 11
  build 26100+ 才支持），否则 Qt 重定向位图的 alpha 不会被启用，DWM 材质会
  被当作全不透明合成。

### 决定性像素分析（2026-08-06，条纹窗对照）

条纹窗自身已验证：`stripe-probe.png` 中部采样到红/青/黄/蓝 4 种纯色条纹
（`#e53935` / `#00bcd4` / `#fdd835` / `#1e88e5`），证明背景图案源可靠。

三种模式在 `PrintWindow` 合成证据图中的顶部纯背景条（y≈90..110 物理像素）：

| 模式 | 背景主色 | 条纹透出 |
| --- | --- | --- |
| native Desktop Acrylic（dark） | `(69, 69, 70)` | 无（纯色） |
| native Mica（dark） | `(32, 32, 33)` | 无（符合 Mica 不采样窗口后方的预期） |
| solid（dark，对照） | `(32, 33, 36)` | 无（符合纯色预期） |

结论：
- **DWM 材质层已确认生效**——acrylic 与 solid 的背景色差（69 vs 32）恰为
  Windows 11 Desktop Acrylic dark 材质色，mica 与 solid 几乎一致符合
  “Mica 类不透明、只采样壁纸/主题”的官方语义；且 solid 的 composed 图与
  应用内容图逐像素一致，排除了截图管线假象。
- **“模糊透出窗口后方内容”在本机当前状态无法确认**——截图时桌面被
  《全面战争：战锤 3》独占全屏占据（exclusive fullscreen），DWM 会退化/暂停
  acrylic 模糊，topmost 条纹窗也不参与桌面合成。要拿到透出铁证，需在游戏
  退出、静态桌面（最好带纹理壁纸）下重跑上面两条命令，再对比 acrylic 与
  solid 的背景区方差/条纹可见度。

## 5. 已知限制

- `QQuickWindow.grabWindow()` 不含 DWM 合成层；原生材质只能通过
  `PrintWindow(PW_RENDERFULLCONTENT)` 或真实屏幕级截图验证（`QScreen.grabWindow(0)`
  在本机对无边框透明窗口无效）。
- 独占全屏游戏（本机 Warhammer3）期间，DWM 不把其他窗口内容合成为
  acrylic 背景，透出实验必须退出游戏后重跑（见第 4 节）。
- 远程桌面 / 虚拟机 / “透明效果”关闭时，DWM 材质自动回退纯色，实验页会明确
  显示原因而不是假装玻璃生效。
- macOS / Linux 仅预留接口，本轮不做视觉验收。

## 6. 回滚方式

1. 删除 `NativeGlassLab.qml`；
2. 删除 `--native-glass-lab` 分支与 `NativeGlassBridge`；
3. 还原 `windows_backdrop.py` / `AcrylicSurface.qml`；
4. 正式 Shell 从未引用这些实验代码，删除不影响正式功能。
