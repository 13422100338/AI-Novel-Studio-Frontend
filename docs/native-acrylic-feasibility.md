# AI Novel Studio：Windows 原生 Acrylic 可行性结论

> Independent implementation based on Windows DWM public APIs.
> No BlockHelm source code copied.
>
> 依据任务文档《AI-Novel-Studio-BlockHelm式Windows原生Acrylic复现实验-Codex任务-v0.1.md》。
> 项目实际栈是 **PySide6 6.11 + QML**（不是 Electron），本文档把文档中的
> Electron/Chromium 术语映射到等价物后给出结论。

## 1. 环境

| 项目 | 值 |
| --- | --- |
| 操作系统 | Windows 11 25H2（build 26200） |
| 系统“透明效果” | 开（`EnableTransparency=1`） |
| Qt / PySide6 | Qt 6.11.1 / PySide6 6.11.1 |
| 渲染后端 | Qt Quick（RHI），真实桌面会话 |
| 窗口类型 | `QQuickWindow`（ApplicationWindow，无边框） |
| 目标 API | `DwmExtendFrameIntoClientArea` + `DwmSetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE=38, DWMSBT_TRANSIENTWINDOW=3)` |

映射表（Electron 文档 → QML 实现）：

| 文档（Electron） | 本项目等价物 |
| --- | --- |
| `BrowserWindow` | `ApplicationWindow`（QML） |
| `getNativeWindowHandle()` | `window.winId()` |
| `transparent` / `backgroundColor` | `QQuickWindow.setDefaultAlphaBuffer(True)` + `color: "transparent"` |
| Chromium compositor 透明 | Qt Quick 场景图 + 根 wash 半透明层 |
| `backgroundMaterial` | `NativeGlassBridge.apply(kind)`（ctypes DWM 调用） |
| React 根透明 | QML 根层 `windowWash`（bgCanvas alpha 0.15） |
| 打包 | 无 Electron packager；源码/`pip install` 运行，PySide6 自带 |

## 2. 实现内容（GlassLab）

- 独立实验入口：`python -m ai_novel_studio.ui_qml --native-glass-lab`
- `src/ai_novel_studio/ui_qml/qml/NativeGlassLab.qml`：标题、三块半透明卡片、
  正文、控制面板（Native ON/OFF、Acrylic/Mica、深浅主题、前景染色透明度
  0.05–0.45、面板不透明度 0.5–1.0、DWM 日志行）
- `src/ai_novel_studio/ui_qml/bridge/windows_backdrop.py`：
  `extend_frame_into_client_area`（MARGINS=-1）+ `system_backdrop_result`
  （返回 `hwnd_valid / extend_frame_hresult / set_backdrop_hresult /
  backdrop_type`）
- `src/ai_novel_studio/ui_qml/bootstrap.py`：`NativeGlassBridge` 暴露
  `lastBackdropResult`，lab 状态栏实时显示：
  `HWND OK | Extend OK | Backdrop OK | TRANSIENT_WINDOW | Qt OK | Visual PARTIAL`
- 能力检测：build 22621+、透明效果开关、失败自动回退 internal/solid，
  不崩溃、不假装玻璃生效。

## 3. 测试记录

- 单元测试：`tests/ui_qml/test_native_glass_bridge.py`（12）+ 
  `tests/ui_qml/test_native_glass_lab.py`（12，含新滑块/日志面板）
- 全量：`pytest tests/ui_qml -q --basetemp .pytest-tmp` → 217 passed / 35 skipped
- ruff / mypy：全部通过
- 真机 windowed 截图：`scripts/capture_native_glass_lab.py --windowed`，
  六状态全部 `nativeActive=True`；`PrintWindow` 合成证据 + 真实屏幕证据
  （`docs/frontend/screenshots/native-glass-lab-*`）

## 4. DWM 结果

```yaml
native_backdrop_result:
  hwnd_valid: true
  extend_frame_hresult: 0          # DwmExtendFrameIntoClientArea(-1) S_OK
  set_backdrop_hresult: 0          # DwmSetWindowAttribute(38, 3) S_OK
  backdrop_type: TRANSIENT_WINDOW  # Desktop Acrylic
```

## 5. 视觉结果（真机像素证据）

| 模式 | 标题栏背景条 | 说明 |
| --- | --- | --- |
| native Desktop Acrylic（dark） | mean≈76，wash 0.15 时 | 材质色 + 壁纸模糊参与 |
| native Mica（dark） | mean≈32 | 接近纯色，符合 Mica 语义 |
| solid（对照） | mean≈32 | 不透明主题色 |

决定性对照（红/青 split 条纹窗 + 移动窗口）：

| 窗口位置 | 背景条 | 结论 |
| --- | --- | --- |
| 红/青交界 | 混合色 std≈99 | 材质真实采样窗口后方 |
| 纯青半区 | 纯青 (0,188,212) | 颜色跟随后方内容 |

综合判定：**PARTIAL（推荐进入正式产品，作为可选增强）**

- ✅ 窗口后方桌面/程序综合色彩明显参与；
- ✅ 移动窗口时背景实时更新（DWM 系统合成，无 JS/应用轮询）；
- ✅ 非截图伪造（实现只调 DWM API）；
- ⚠️ 模糊轮廓可见性弱——Windows 11 Desktop Acrylic 模糊半径大，细纹理
  会被抹平为近均匀色调；这与 Win11 开始菜单/商店一致，是系统材质特性，
  不是实现缺陷；
- ⚠️ 深色主题下材质差异明显，浅色主题下对比度低（浅色材质接近白色）。

## 6. 已接入正式 Shell

- `App.qml` + `bootstrap.py`：`python -m ai_novel_studio.ui_qml` 默认启用
  DWM Desktop Acrylic（无边框 + 自绘标题栏 + wash 0.15）；`--no-glass` 回退；
  失败路径保持不透明。
- 证据：`docs/frontend/screenshots/glass-shell-*`，屏幕级标题栏背景条
  acrylic std≈55 vs solid std≈12。

## 7. 已知限制

- 独占全屏游戏会接管显示，期间无法观察材质（本机 Warhammer3 验证过）。
- 远程桌面 / 虚拟机 / “透明效果”关闭：自动回退纯色，UI 明确显示原因。
- `QQuickWindow.grabWindow()` 不含 DWM 合成层；验证须用真实屏幕截图或
  `PrintWindow(PW_RENDERFULLCONTENT)`。
- 无边框窗口自带标题栏被替换为自绘标题栏；最小化/最大化/拖动/resize
  经 `startSystemMove` / `startSystemResize` 走系统路径。

## 8. 结论

**YES（可在 Client Area 真正暴露 Desktop Acrylic）**，且已默认接入正式
写作 Shell。效果上限由 Windows 系统材质决定（色调跟随 + 大半径模糊），
达不到“iOS 式轮廓清晰玻璃”；若要轮廓级玻璃，需另开“应用内壁纸模糊”
实验（internal glass 路线），与本次 native 实验相互独立。
