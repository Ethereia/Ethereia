class_name RegionData
extends Resource
## 区域数据表 Schema（doc 06 / doc 29 §2.9 v1.0 冻结）
## Location 内嵌 Dictionary（11 字段）：
## {id, position: Vector2i, location_type, level_range, terrain, tags, resources, encounters, factions, quest_hooks}

@export var id: String = ""                            # region_ 前缀
@export var display_name: String = ""
@export var terrain: String = ""                       # 主地形
@export var level_range: Vector2i = Vector2i(1, 10)    # 建议等级区间（x=低 y=高）
@export var tags: Array[String] = []                   # 生态/主题标签
@export var danger_level: int = 0                      # 危险度 0~100（影响 BGM 与事件）
@export var resources: Dictionary = {}                 # {resource_id: 丰度}
@export var locations: Array[Dictionary] = []          # 地点列表（11 字段结构）
@export var factions_present: Array[String] = []       # 在场势力（faction_id）
@export var ambient_bgm: String = ""                   # 环境 BGM 文件名（assets/audio/music/ 下）
@export var map_layer_paths: Dictionary = {}           # 地图分层 {layer: 路径}，terrain/roads/rivers/...
