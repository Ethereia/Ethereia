class_name SkillData
extends Resource
## 神通（战斗技能）数据表 Schema（doc 29 §2.3 v1.0 冻结）
## 成本模型（doc 08 缺口补充，决议#2）：
## 法术系消耗 mp_cost（灵力），近战/炼体系消耗 stamina_cost（体力），混合技能可同时消耗

enum SkillType { SINGLE, AOE, CONTROL, DEFENSE, DASH, SUMMON, ENVIRONMENT, KARMA }
## 8 类型：单体/群体/控制/防御/位移/召唤/环境/因果（doc 03 §7）

@export var id: String = ""                            # skill_ 前缀
@export var display_name: String = ""
@export var skill_type: SkillType = SkillType.SINGLE
@export var element: String = ""                       # 五行/特殊属性（参与克制与状态）
@export var power: float = 10.0                        # 伤害公式 skill_power（doc 08）
@export var mp_cost: int = 0                           # 灵力消耗
@export var stamina_cost: int = 0                      # 体力消耗（近战/炼体，决议#2）
@export var cooldown: float = 1.0                      # 冷却秒数
@export var cast_range: float = 120.0                  # 施放距离（像素）
@export var aoe_radius: float = 0.0                    # >0 为范围技
@export var status_effects: Array[Dictionary] = []     # [{status_id, chance 0~1, duration 秒, power}]
@export var scaling_stats: Array[String] = []          # 参与伤害加成的属性（atk/m_atk/...）
@export var dao_heart_requirement: Dictionary = {}     # {维度: 最低值}，高阶神通门槛
@export var description: String = ""
@export var icon: String = ""                          # 图标路径（空=占位）
