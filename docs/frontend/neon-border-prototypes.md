# Neon 边框原型（A / B）结论记录

> 范围：只读审计与独立原型，不修改正式 UI / Agent 卡片。
> 分支：`codex/frontend-agent-c1`，独立 commit，未合并 main。

## 背景

现有 Canvas 光点实现（`b163db6`）虽通过四边与路径连续测试，但真机视觉在
圆角处呈现机械转向。本任务冻结该实现，改为两个独立原型验证转角连续性与
正式候选方案。

## 原型 A：PathRectangle + PathInterpolator

- 文件：`scripts/prototypes/neon/prototype_a_pathinterpolator.qml`
- 捕获：`scripts/prototypes/neon/capture_prototype_a.py`
- 结论：Qt 原生路径插值在转角处位置/方向连续（401 采样最大角度跳变
  8.588°@0.25% 进度步进），证明原生路径可消除手工四直线四圆弧的机械转向。
- 产物：`docs/frontend/screenshots/prototype-a/`（full-lap GIF、
  corner-0.25x GIF、angle-report、player.html、72 帧序列）。

## 原型 B：ShaderEffect + 预编译 qsb（正式候选）

- 组件：`scripts/prototypes/neon/NeonRoundedBorderEffect.qml`
- 演示窗口：`scripts/prototypes/neon/prototype_b_shader.qml`
- Shader 源：`neon_rounded_border.vert` / `neon_rounded_border.frag`
- 预编译产物：`neon_rounded_border.qsb`（合并版）、
  `neon_rounded_border_frag.qsb`（组件实际引用）
- 捕获：`scripts/prototypes/neon/capture_prototype_b.py`

### 逐像素方案

fragment shader 单次计算：

1. 圆角矩形 SDF（IQ `sdRoundRect`）；
2. 边框 mask（中心线距离的指数衰减）；
3. 边框连续周长坐标（8 段：四直线 + 四 90° 圆弧，同一连续函数）；
4. 当前 phase 与像素周长位置的环形距离；
5. 核心亮度（高斯）；
6. 平滑拖尾（负向指数衰减）；
7. 低透明外辉光（SDF 高斯）。

`UniformAnimator` 驱动 `uPhase` 0→1（渲染线程），转角由同一周长函数处理，
无 QML 光点对象、无 rotation 分段切换。

### 关键踩坑（本环境实测）

- `uSize` 必须用 `Qt.vector2d(w, h)`，`Qt.size()` 会经 QML 转换失败变成
  `(0,0)`，导致 SDF/perimeter 全部失效、shader 输出全透明（曾误判为
  shader 未渲染）。
- `QQuickShaderEffect::Status` 在 QML 绑定中不可靠（已编译渲染仍读 0）；
  shader 失败检测以 `effect.log` 为空 + 渲染实测为准，正式接线时应改用
  `onStatusChanged` + `log` 日志并在首帧后确认绘制。
- qsb 编译：`qsb --qt6 -b -o out.qsb vert.frag`；vert/frag 的 std140
  uniform block 必须完全一致；ShaderEffect 引用 qsb 用 `Qt.resolvedUrl`。
- offscreen/software 后端下 ShaderEffect 不绘制，验收必须以 windowed 模式
  真机运行。
- 孤立探针窗口在 resize 后 `grabWindow` 返回空白（本环境问题），resize
  验收改在主演示窗口完成。

### 验收产物

`docs/frontend/screenshots/prototype-b/`：

- `prototype-b-full-lap.gif`：72 帧一圈（thinking 循环），逐帧 71/71 有
  变化、69 帧不同，光点环绕四边；
- `prototype-b-corner-0_25x.gif`：48 帧转角慢放（0.25x 播放），覆盖
  上边→右上角→右边；
- `prototype-b-success-single.gif` / `prototype-b-error-single.gif`：
  单次扫过（各 60 帧）；
- `prototype-b-reducemotion-static.png` / `prototype-b-safe-static.png`：
  静态高亮回退；
- `prototype-b-idle.png`：无边框；
- `prototype-b-resize-760x520.png` / `-1080x620.png`：窗口放大后边框
  bbox 仍精确贴合 320×160 卡片（DPR 2 下 640×320 device px）；
- `prototype-b-report.txt`、`prototype-b-player.html`（1x / 0.25x 播放）。

DPR 100/125/150%：shader 全部使用逻辑坐标（`qt_TexCoord0 * uSize`），
渲染按 devicePixelRatio 统一缩放，逻辑坐标不变式已由 resize 验证覆盖。

## 运行方式（worktree 根目录）

```powershell
.\\.venv\\Scripts\\python.exe scripts\\prototypes\\neon\\capture_prototype_a.py
.\\.venv\\Scripts\\python.exe scripts\\prototypes\\neon\\capture_prototype_b.py
```

两个脚本都必须以 windowed 会话运行（不要设置 `QT_QPA_PLATFORM=offscreen`
或 `QT_QUICK_BACKEND=software`）。

## 未决事项

- 原型 B 达到用户肉眼验收前，不接入正式 Agent 卡片（本任务未做任何正式
  UI 修改）。
- Qt Quick Effect Maker 离线版本机未找到；如需 `.qep` 源文件，需在安装
  QQEM 后从 `.frag/.vert` 导入生成。
