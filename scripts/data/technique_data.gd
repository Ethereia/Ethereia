class_name TechniqueData
extends Resource
## 功法数据表 Schema（doc 29 §2.2 v1.0 冻结）
## 功法是"带副作用的规则包"而非技能树（doc 03 §6）

enum TechType { MAIN, AUX, BODY, SOUL, FORMATION, ALCHEMY, CRAFTING, TALISMAN, NETHER }
## 9 类型：主修/辅修/炼体/神魂/阵法/丹道/器道/符道/冥道

enum Grade { FAN, HUANG, XUAN, DI, TIAN, SHENG, XIAN, JIN }
## 8 品质：凡/黄/玄/地/天/圣/仙/禁

@export var id: String = ""                            # technique_ 前缀
@export var display_name: String = ""
@export var tech_type: TechType = TechType.MAIN
@export var grade: Grade = Grade.FAN
@export var element_affinity: Array[String] = []       # 属性倾向，如 ["水","冰"]
@export var attribute_tendency: Dictionary = {}        # {stat: 百分比}，如 {"m_def": 0.20}
@export var cultivation_efficiency: float = 1.0        # 修炼效率倍率
@export var spirit_root_requirement: Dictionary = {}   # {元素: 最低纯度}，灵根适配因子输入
@export var active_skill_ids: Array[String] = []       # 附带神通（skill_id 列表）
@export var passive_effects: Array[Dictionary] = []    # [{stat, op, value}]
@export var breakthrough_modifiers: Dictionary = {}    # 对突破因子的修正 {factor: ±值}
@export var side_effects: Array[String] = []           # 副作用（描述或规则id），如突破概率冻结灵力
@export var hidden_trait: String = ""                  # 隐藏特性
@export var hidden_trait_condition: String = ""        # 隐藏特性触发条件（如"无杀生道心"）
@export var cultivation_progress_max: int = 100        # 功法完成度上限（突破因子输入）
@export var description: String = ""
