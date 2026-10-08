class_name BuildingData
extends Resource
## 建筑数据表 Schema（doc 09 / doc 29 §2.5 v1.0 冻结）
## 首发建筑 11 栋，全部 5 级；等级相关配置用数组按下标取（下标0=1级）

@export var id: String = ""                            # building_ 前缀
@export var display_name: String = ""
@export var max_level: int = 5
@export var upgrade_cost: Array[Dictionary] = []       # 每级升级消耗 {resource_id: 数量}
@export var upgrade_time_days: Array[int] = []         # 每级工期（天）
@export var prestige_requirement: Array[int] = []      # 每级声望门槛
@export var prereq_building: Dictionary = {}           # {building_id: 最低等级} 前置建筑
@export var production: Dictionary = {}                # 每月产出 {resource_id: 每级数量}
@export var upkeep: Dictionary = {}                    # 每月维护 {resource_id: 每级数量}
@export var unlock_effects: Array[Dictionary] = []     # 解锁功能 [{effect: String, level: int}]，如丹房→炼丹
@export var sprite_lv01: String = ""                   # 1~5 级外观路径（空=占位，命名 building_<id>_lv0N）
@export var sprite_lv02: String = ""
@export var sprite_lv03: String = ""
@export var sprite_lv04: String = ""
@export var sprite_lv05: String = ""
@export var description: String = ""
