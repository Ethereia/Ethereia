# AGENTS.md — 仙冥大陆 Ethereia · AI 开发上下文

> 本文件是所有 AI 辅助开发的**第一读取文件**（doc 26）。内容与 docs/Ethereia_Godot_AI_Docs/ 文档集保持同步；两者冲突时以文档集为准并回改本文件。

## 1. 项目身份（Layer 0）

- **定位**：2D 单机修仙策略 RPG（个人 RPG + 宗门经营 SLG + 世界模拟）
- **引擎**：Godot 4.7-stable | **语言**：GDScript | **平台**：Windows
- **沟通**：与用户交流使用简体中文；代码注释使用简体中文
- **当前阶段**：阶段0 技术骨架（路线图见 19 号文档，验收见 27 号文档）

## 2. 每次任务工作流

```text
read AGENTS.md → read relevant docs → inspect project → implement → test → report
```

报告格式（原则 B，doc 00 §5）：修改了什么 / 为什么 / 影响哪些文件 / 如何测试 / 兼容性风险。

## 3. 文档索引（Layer 1-2）

全部位于 `docs/Ethereia_Godot_AI_Docs/`：

| 优先级 | 文档 |
|---|---|
| 常驻必读 | 00 项目总览与索引 · 01 GDD · 15 技术架构 · 16 数据与存档 · 17 AI辅助开发规范 · 18 目录与命名 |
| 按当前系统读取 | 03 修仙 · 05 势力 · 07 玩法循环 · 08 战斗 · 09 宗门 · 10 经济 · 11 任务事件对话 · 12 UI/UX |
| 阶段门禁 | 19 MVP路线图 · 27 垂直切片规格 · 21 测试与验收 · 23 第一周任务 |
| 资源协作 | 13 美术规范 · 14 音乐音频 · **28 资源需求追踪（每阶段启动时对照提示用户补充资源）** |
| 流程 | 24 决策记录（重大决策必须登记） · 25 版本控制 · 02 世界观（内容类 AI 常驻） |

## 4. 目录结构

```text
assets/          # art/ audio/(music,sfx) fonts/ vfx/
data/            # 9 张数据表目录：characters items skills techniques buildings quests events factions regions
docs/            # 设计文档集
scenes/          # main/ world/ battle/ characters/ buildings/ ui/
scripts/         # core/ gameplay/ combat/ cultivation/ sect/ quest/ world/ ui/ utils/
shaders/  tests/  tools/
```

## 5. 命名规范（doc 18）

- 脚本文件 `snake_case.gd`；类名 `PascalCase`；变量 `snake_case`；常量 `UPPER_SNAKE_CASE`；信号 `snake_case`
- 场景 `PascalCase.tscn`；数据 ID 全小写 `snake_case` 且**永不因改名变更**
- 禁止：`final_final.gd`、`test2.gd`、`new_script.gd`、`temp.gd` 等无意义命名

## 6. 架构（Layer 1，doc 15）

五层：Presentation → Gameplay → Domain → Data → Persistence

Autoload（初始化顺序即依赖顺序，勿随意调换）：

```text
EventBus → SettingsManager → DataManager → SaveManager → TimeManager
→ AudioManager → SceneManager → GameManager → (_mcp_game_helper 插件自带)
```

- 跨系统通信一律 Signal/EventBus，禁止直接跨系统调用私有成员
- 数值公式集中管理（如 combat_formula.gd），禁止把数据硬编码进战斗脚本
- 场景脚本通过 `@onready` + 节点路径绑定，改场景必须同步检查脚本路径

## 7. 存档纪律（doc 16）

- 需要持久化的系统：实现 `get_save_state()` / `load_save_state()` 并 `add_to_group("savable")`
- 只存状态（ID/数量/变量），不存静态定义（名称/描述/图标由 DataManager 按 ID 重建）
- `SaveManager.SAVE_VERSION` 变更必须提供链式迁移函数 `_migrate_vN_to_vN+1()`
- 写入必须走 SaveManager 的原子写入（temp → flush → 替换，旧档留 .bak）

## 8. 禁止事项

- 不得随意修改 project.godot、重命名公共类、移动资源、改核心接口而不更新调用方
- 不得创建巨型 Manager；不得在 Autoload 里堆业务逻辑
- 不得提交：`*.pck`、`/build/`、`export/`、`export_credentials.cfg`、`override.cfg`（含密钥/产物）
- MVP 阶段禁止：联机、Mod 系统、程序生成世界、3D、MMO（doc 19 §明确禁止）
- 里程碑未验收不得扩展内容（doc 27 §5：切片不达标只优化不扩展）

## 9. 测试与验收

- 功能完成定义与回归测试：21 号文档
- 运行验证：Godot-MCP（`project_run` 启动 → `logs_read(source="game")` 查日志 → `editor_screenshot` 验证画面）
- 提交前：25 号文档 §3 发布检查清单
- 资源里程碑：对照 28 号文档清点"占位中"资源

## 10. 版本控制（doc 25）

- 分支：`main`（稳定）/ `develop`（日常开发）/ `feature/*`、`fix/*`
- Commit 前缀：`feat:` `fix:` `refactor:` `docs:` `art:` `audio:` `test:` `build:`
- 发布版本号：0.1.0 Prototype → 0.2.0 Vertical Slice → 0.5.0 Alpha → 0.8.0 Beta → 1.0.0
