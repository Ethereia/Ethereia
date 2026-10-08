class_name EventData
extends Resource
## 事件数据表 Schema（doc 11 / doc 29 §2.7 v1.0 冻结）
## 事件由世界状态驱动：conditions 读取世界变量（如 region.monster_pressure）
## 效果统一格式 {target, key, op, value}，经 EventBus.world_state_changed 广播（阶段7消费）

enum Trigger { STATE_CONDITION, MANUAL, SCHEDULED }

@export var id: String = ""                            # event_ 前缀
@export var title: String = ""
@export var description: String = ""
@export var priority: int = 0                          # 同帧多事件按优先级触发
@export var cooldown_days: int = 0                     # 触发后冷却（天）
@export var trigger: Trigger = Trigger.STATE_CONDITION
@export var conditions: Array[Dictionary] = []         # [{key, op(">="/"<="/"=="), value}]
@export var choices: Array[Dictionary] = []            # [{text, effects, delayed_effects, hidden_effects, requirements, hint}]
                                                       # 三层结果（doc 11）：即时/延迟/隐藏
@export var effects: Array[Dictionary] = []            # 无选项事件直接生效的效果
@export var involved_npcs: Array[String] = []          # 涉及 NPC（char_id）
@export var involved_factions: Array[String] = []      # 涉及势力（faction_id）
