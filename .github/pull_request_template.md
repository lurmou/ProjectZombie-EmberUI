# PR 验收

## Linear 关联
<!-- 独立完成用 Closes；阶段性交付用 Part of 或 Refs。 -->
Closes EMB-xxx

## 变更与验收范围
-

## 检查结果
<!-- 每项注明通过、失败或不适用及原因。 -->
- [ ] `./build.ps1`（包含 OpenGL 画廊）
- [ ] `node ../.workbuddy/tools/pz.mjs preflight .`（修改 Lua 时）
- [ ] 相关画廊截图回读（修改 UI 布局或视觉时）
- [ ] `node ../.workbuddy/tools/pz.mjs doclink <文件...>`（修改 Markdown 时）
- [ ] 游戏内验收：步骤与结果 / 不适用

## 变更文件统计及风险
```text
（粘贴 git diff --stat）
```
- 高风险点：
- Linear PR 关联及状态：
- `workshop.txt` 未写入更新日志：
