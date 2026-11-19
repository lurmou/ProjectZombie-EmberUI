# EmberUI 协作规则

> 适用范围：本仓库；同时遵循上级 Workshop 的 AGENTS.md 和用户当前指令。

## 任务、分支与验收

- 开发前在 Linear `EmberRoutesV2` 团队的 `EmberUI` 项目读取或创建任务，确认验收范围及未完成的 `Blocked by`。无法访问 Linear 时报告障碍，不伪造任务或声称依赖已核实；只继续不依赖任务信息的只读准备。
- 纯问答和只读排查不建 PR；用户只要求记录点子或报错时，写入 Linear 并返回编号，不改代码。真实异常的诊断与处理遵循适用的上级规则和用户要求。
- 修改前检查 Git 状态并从最新远程 `main` 建任务分支，不直接在 `main` 修改或提交。工作区有改动时保留原样；经用户授权可在独立 worktree 从最新 `main` 开始。需要带入已有改动或未获隔离授权时先确认。
- 涉及其他仓库时分别建任务分支和 PR；有实际前置依赖时在 Linear 记录，先交付并合并前置 PR。无需因共享团队而混用项目或修改另一个仓库。
- PR 标题和提交信息包含 `EMB-xxx`；独立完成任务在 PR 正文写 `Closes EMB-xxx`，阶段性贡献写 `Part of EMB-xxx` 或 `Refs EMB-xxx`。按 [PR 模板](.github/pull_request_template.md) 填写结果；公开仓库的 PR 和 Linear 自动回链不得包含不适合公开的信息。
- AI 默认只创建或更新 PR；用户审阅、必要时实机验收后合并，除非用户当次明确授权代为合并。合并前返工留在原 PR 分支。创建 PR 后回读关联及状态；同步可能延迟，不重复创建任务或 PR。提交用户验收时核对 `In Review`，必要时手动设置；合并后核对 `Done` 和远程分支删除结果。

## 检查与交付

- 仓库构建运行 `./build.ps1`：它执行隔离和双语检查、Kahlua 编译与测试、OpenGL 画廊及打包。`-SkipPreview` 会跳过画廊，不得记作完整构建通过。
- 修改 Lua 时运行 `node ../.workbuddy/tools/pz.mjs preflight .`；修改 Markdown 时对具体变更文件运行 `node ../.workbuddy/tools/pz.mjs doclink <文件...>`。共享工具先用 `node ../.workbuddy/tools/pz.mjs list` 查询入口。
- 开发前搜索本仓库中相关实现；交付说明复用入口，未复用时说明原因。修改 Lua 时运行 `./tools/check-duplication.ps1`，PR 目标不为 `origin/main` 时指定 `-BaseRef <目标分支引用>`。检查新增相似片段并说明处理或保留原因；相似本身不阻断，工具、基准或扫描失败时报告未完成。
- 修改 UI 布局或视觉时，运行 `./tools/preview-ui.ps1` 或使用完整构建生成的画廊，并回读相关截图；构建或截图不代替游戏内验收。翻译键保持 CN/EN 成对、位置占位符一致。
- 门禁失败时报告原始错误，修复后重跑；不能将跳过、缺依赖或替身测试写成通过。交付注明 PR 链接、文件统计、检查结果、实机步骤及风险；更新日志不写入 `workshop.txt`。
