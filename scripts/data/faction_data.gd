class_name FactionData
extends Resource
## 势力数据表 Schema（doc 05 / doc 29 §2.8 v1.0 冻结）
## 关系五字段允许"讨厌但害怕且愿意交易"的矛盾状态（doc 05）

enum FactionType { MAJOR_SECT, PLAYER_SECT, CITY, WILDERNESS }
## 大宗门 / 玩家宗门 / 城邦 / 野外势力

@export var id: String = ""                            # faction_ 前缀
@export var display_name: String = ""
@export var faction_type: FactionType = FactionType.MAJOR_SECT
@export var ideology: String = ""                      # 理念（影响外交与弟子契合）
@export var relations: Dictionary = {}                 # {faction_id: {relation_score(-100~100), trust, fear, trade, war_state}}
@export var territory: Array[String] = []              # 控制区域（region_id）
@export var ai_profile: Dictionary = {}                # {aggression, expansion, trade_preference} 各 0~100
@export var description: String = ""
