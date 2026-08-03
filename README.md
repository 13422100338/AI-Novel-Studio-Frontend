# AI Novel Studio 前端（独立仓库）

> 从 `AI-Novel-Studio` 前端工作分支（`codex/frontend-wave-f1`）抽离的**独立前端**。
> 本仓库只含前端代码与测试，不含后端 Domain / Application / Infrastructure。

## 这是什么

一个本地优先的长篇小说写作软件的现代桌面前端，技术栈为 **Python/PySide6 + QML 外壳 + 内嵌
Chromium（Qt WebEngine）承载 Tiptap/ProseMirror 编辑器**。产品形态是桌面应用，不是网页应用；
WebEngine 只是编辑器组件。

当前已完成（截至抽取提交 `eb1cb61`）：

- F1：QML 单窗口 Shell（导航轨 / 章节侧栏 / 正文工作区 / AI 抽屉 / 状态栏 / Design Tokens / 基础组件）
- F2：只读项目接线（`ProjectWorkspaceService`）
- F3：真实保存 + 修订冲突恢复
- F4–F8：AI 草稿候选层、后台生成 + 取消、生成配置、草稿三视图、Token/费用显示
- F9–F18：人物/记忆/审校只读概览与列表、人物时间线/详情、审校证据定位与忽略/误报、记忆详情、草稿编辑后接受
- Phase 1：受限 Markdown Schema + 100 组黄金样本往返、20 万字符压力、1000 次编辑可靠性、800ms 防抖保存、QWebChannel/runJavaScript 桥、WebEngine 安全加固
- P2：WebEngine 默认入口、停靠式 AI 抽屉、剧情商讨聊天面板（Mock 回复）

## 目录

```text
src/ai_novel_studio/ui_qml/
├── bootstrap.py                     QML 入口（默认 WebEngine，--textarea 回退）
├── bridge/                          Facade、DTO、列表模型、草稿端口、编辑器桥
│   ├── mock_novel_studio_facade.py  QML 唯一数据边界
│   ├── draft_port.py / draft_coordinator.py   草稿生成端口与后台协调器
│   ├── editor_bridge.py             WebChannel 桥（协议 v1、哈希/大小校验）
│   └── models/                      各 QAbstractListModel
├── editor_runtime.py                WebEngine 脚本注入 / 资源 / 安全设置
├── editor_web/                      Tiptap/ProseMirror 编辑器（npm，独立构建）
│   ├── src/schema.ts                受限小说 Schema
│   ├── src/markdown.ts              MarkdownCodec（prosemirror-markdown）
│   ├── src/editor-core.ts           DOM-free 编辑核心 + 防抖保存 + 快照
│   └── src/editor.ts                浏览器入口 + 桥表面
└── qml/                             App.qml + components/ + pages/
tests/ui_qml/                        前端测试（pytest-qt + QML 冒烟）
docs/frontend/                       审计、逐 Wave 交付记录、接线点、人工验收
scripts/capture_frontend_f1_screenshots.py
```

## 运行

```powershell
# 1) Python 依赖
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[dev]"

# 2) 编辑器 bundle
cd src\ai_novel_studio\ui_qml\editor_web
npm install
npm run build          # 产出 dist/（editor.js + html + css + qwebchannel.js + prosemirror.css）
cd ..\..\..\..

# 3) 启动（默认 WebEngine 编辑器；--textarea 回退 QML 文本编辑器）
.\.venv\Scripts\python.exe -m ai_novel_studio.ui_qml
```

## 测试

```powershell
python -m pytest tests/ui_qml -q --basetemp .test-temp/pytest-base
python -m ruff check src tests scripts
python -m mypy            # MYPYPATH=src
cd src\ai_novel_studio\ui_qml\editor_web && npm test && npm run typecheck
```

## 与后端的边界（重要）

本仓库是**纯前端**。打开项目、保存、审校状态、草稿采用等会调用后端仓库的既有应用服务
（签名见 `docs/frontend/interface_contracts.md`）；模型生成在默认运行时**不注入端口**，
UI 如实提示「模型生成端口未配置」。要完整运行需把本前端挂到原仓库并注入
`ProjectSessionDraftPort` / `ProjectGenerationSession`。

许可证：前端代码 MIT（与主仓库一致）；`editor_web/src/qwebchannel.js` 来自 Qt
（LGPL-3.0/GPL，见 `THIRD_PARTY_NOTICES.md` 引用与上游头注释）。
