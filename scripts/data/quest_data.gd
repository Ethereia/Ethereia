class_name QuestData
extends Resource
## 任务数据表 Schema（doc 11 结构直译 / doc 29 §2.6 v1.0 冻结）
## Objective 类型 10 种：到达|对话|战斗|收集|修炼|建造|研究|选择|时限|NPC状态
## 效果统一格式 {target, key, op, value}（与 EventData 一致）

@export var id: String = ""                            # quest_ 前缀
@export var display_name: String = ""
@export var description: String = ""
@export var giver: String = ""                         # 发布者 char_id（无则空）
@export var requirements: Array[Dictionary] = []       # 接取条件 [{key, op, value}]
@export var objectives: Array[Dictionary] = []         # 目标 [{type, target_id, count, params}]
@export var rewards: Array[Dictionary] = []            # 奖励 [{target, key, op, value}]
@export var failure_conditions: Array[Dictionary] = [] # 失败条件
@export var consequences: Array[Dictionary] = []       # 失败/放弃后果（允许失败设计，doc 01 §8）
@export var next_quests: Array[String] = []            # 后续任务 quest_id 链
