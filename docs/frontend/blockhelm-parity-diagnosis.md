# BlockHelm Parity Mode 诊断结论（Qt Quick vs WPF Demo 二分测试）

> 依据《AI-Novel-Studio-BlockHelm-Parity-Mode-DeepSeek诊断实施指南-v0.1.md》。
> 本轮只做一件事：在极简同条件下回答
> "Qt Quick + DWM 能否达到用户认可的 WPF BlockHelm Demo 玻璃视觉"。

## 1. 结论（先行）

**Qt + DWM 路线技术上可行（Parity PASS）。**

极简 Parity 页面在真机上四模式行为全部符合预期：

| 模式 | DWM | 真机屏幕条（title-bar 纯 wash 区） | 判定 |
| --- | --- | --- | --- |
| A solid | none | mean=(55,55,55) 深灰，std 21（卡片文字） | 基线 ✓ |
| B transparent | none | mean=(216,73,71) 红 -- 纯 Qt alpha 透出后方红色条纹 | Qt alpha 生效 ✓ |
| C acrylic | TransientWindow | mean=(94,94,94) 中性灰，std 17 -- 材质混合后方红色 | DWM 生效 ✓ |
| D parity | TransientWindow | mean=(102,102,102) std 27 -- 材质 + 中性灰卡片 | 接近 WPF Demo ✓ |

证据图（同一固定红/青 split 背景、同一窗口）：

```text
docs/frontend/screenshots/blockhelm-parity-{solid,transparent,acrylic,parity}.png
```

因此：**正式 UI 失败不属于 "Qt/RHI/DWM 合成链" 问题**，而是正式 UI 自身
把系统玻璃盖住了（见第 3 节审计）。

## 2. 新增交付物

- src/ai_novel_studio/ui_qml/qml/BlockHelmParity.qml：极简中性灰 Parity 页
  （A/B/C/D 四模式按钮，固定灰 palette，无 Theme/无 blur/无装饰）
- bootstrap.py：--blockhelm-parity 启动入口
- scripts/capture_blockhelm_parity.py：固定背景四模式真机截图 + 统计
- tests/ui_qml/test_blockhelm_parity.py：加载/默认模式/模式切换/卡片可见性
- 本诊断文档

启动方式：

```powershell
cd C:\Users\钟子诚\.codex\worktrees\frontend-clean
.\\.venv\\Scripts\\python.exe -m ai_novel_studio.ui_qml --blockhelm-parity
```

## 3. NativeGlassVisualLayerAudit（正式 Shell native 模式仍可见层）

| # | 文件 | 对象 | native 模式可见 | 颜色 / alpha | 覆盖面积 | 处理 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | App.qml | windowWash | 是 | bgCanvas @ 0.15 | 全窗口 | 保留（可再降） |
| 2 | App.qml | workspaceHost | 是（native 时 transparent） | transparent | 中央大部 | 保留 |
| 3 | App.qml | backgroundLayer (BackdropLayer) | 否（已隐藏） | -- | -- | 已修 |
| 4 | WritingPage | 根 Rectangle | 是（native 时 transparent） | transparent | 写作页 | 保留 |
| 5 | WritingPage | manuscriptHost (AcrylicSurface) | 是 | nativeGlassFill @ 0.42 | 正文区 | 保留（正文纸面另议） |
| 6 | NovelEditorView | WebEngineView | 是 | bgEditor（WebEngine 模式不透明） | 正文大部 | **主要污染源** |
| 7 | NavigationRail | AcrylicSurface | 是 | nativeGlassFill @ 0.42 | 导航 | 保留 |
| 8 | ContextSidebar / sidebarHost | AcrylicSurface | 是 | nativeGlassFill @ 0.42 | 侧栏 | 保留 |
| 9 | AgentDock | panelSurface | 是 | nativeGlassActive ? 0.42 : 0.86-0.94 | 右侧 dock | 保留 |
| 10 | statusBar | Rectangle | 是 | bgSurface 不透明 | 3% | 可改半透明 |

## 4. 正式 UI 污染源排名（Parity PASS 后）

按指南第 10 节修复顺序，当前判断：

1. **Paper Theme 强染色**（指南 2.2）：windowWash 0.15 + panel 0.42 都读
   bgCanvas/bgSurface（暖白 #FBF8F0 系），叠加后是奶油色实体，不是中性灰玻璃。
2. **WebEngine 编辑器不透明**（指南 2.1）：NovelEditorView.backgroundColor =
   bgEditor（Paper 下 #FFFDF7），占据正文最大面积，天然盖住 DWM。
3. **框架 Surface 偏厚**：sidebarHost/manuscriptHost 等在 native 模式下
   透明度 0.42，且部分仍携带 LiquidLights/Noise 等历史装饰层。
4. **状态栏等小面积不透明**：bgSurface 实色。

## 5. 修复顺序（下一步，仅在 Parity PASS 前提下）

```text
Step 1  正式 Native Glass 主题语义独立（nativeGlass.* tokens，不再复用 Paper）
Step 2  框架 Surface 变薄（0.42 -> 0.30~0.36，去装饰层）
Step 3  降低大面积不透明覆盖（编辑器外框、状态栏）
Step 4  WebEngine 编辑器单独处理（保持 90%~97% 可读，外框玻璃化）
Step 5  最后才恢复装饰层
```

## 6. 工作假设

> Qt + DWM 足够接近 WPF Demo；正式 UI 失败主要来自暖色 Paper Theme、
> 大面积不透明 WebEngine、Surface tint 与历史玻璃模拟层。该假设已被本
> Parity 测试验证为成立（Parity 页四模式行为正确，差异在正式 UI 覆盖层）。
---

## 7. ��ʽ Shell �޸���ָ�� ��10����ʵʩ��

Parity PASS ��ָ�� ��10 ˳����أ�

- **Step 1 ���� Native Glass ��������**��ָ�� ��11����ThemeProvider ����
  `Theme.tokens.nativeGlass.*`��windowTint/panelTint/sidebarTint/editorTint/
  border/text����**���Իҡ����� Paper ů��**��windowWash��panel fill��
  sidebar��statusBar��AgentDock��editor ����ȫ���Ķ� nativeGlass tokens��
- **Step 2 ��� Surface �䱡**��AcrylicSurface native ģʽֱ������
  panelTint��#AARRGGBB �Դ� alpha��Լ 29%���������� native ģʽ�µ�
  NoiseOverlay ��װ�β㣻���� manuscriptHost �ø���͸���� editorTint
  ��Լ 88%�����ֿɶ���
- **Step 3 ���Ͳ�͸������**��workspaceHost/WritingPage ������ native ʱ
  ͸������ǰ��������statusBar �İ�͸�� sidebarTint��
- **Step 4 WebEngine �༭��**��NovelEditorView �� backgroundColor ��
  Web ҳ --editor-bg �� native ģʽ���� nativeGlass.editorTint�����Կɶ�
  ֽ�棩��������ů�� #FFFDF7��
- Step 5 װ�β�ָ������ֲ�����BackdropLayer �� native ģʽ�±������أ���

��֤��2026-08-08���̶���/�౳������

```text
��ʽ Shell acrylic��dark����title-bar �� mean=(87,87,87) ���Ի�
��ʽ Shell solid��dark����  title-bar �� mean=(243,239,230) Paper ů��
```

�������ԣ�ů��Ⱦɫ���Ƴ�����ʽ������ϵͳ Acrylic �³������ԻҲ�����
