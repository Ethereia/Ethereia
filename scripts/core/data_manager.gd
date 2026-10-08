## 数据管理器：加载 data/ 下静态数据表（Resource .tres / JSON），提供只读查询
## 设计原则 A（doc 00 §5）：数据与逻辑分离，内容一律数据驱动，不硬编码
extends Node

const DATA_ROOT := "res://data/"
const TABLES: Array[String] = [
	"characters", "items", "skills", "techniques", "buildings",
	"quests", "events", "factions", "regions", "dialogues",
]

## _cache[table][id] -> Dictionary(JSON) 或 Resource(.tres)
var _cache: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	_cache.clear()
	for table in TABLES:
		_cache[table] = _load_table(table)

func reload_table(table: String) -> void:
	if table in TABLES:
		_cache[table] = _load_table(table)

func get_entry(table: String, id: String) -> Variant:
	if _cache.has(table) and _cache[table].has(id):
		return _cache[table][id]
	push_warning("DataManager: 未找到条目 %s/%s" % [table, id])
	return null

func get_table(table: String) -> Dictionary:
	return _cache.get(table, {})

func _load_table(table: String) -> Dictionary:
	var result: Dictionary = {}
	var dir_path := DATA_ROOT + table + "/"
	if not DirAccess.dir_exists_absolute(dir_path):
		return result
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("DataManager: 无法打开目录 %s" % dir_path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var id := file_name.get_basename()
			if file_name.ends_with(".json"):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir_path + file_name))
				if parsed is Dictionary:
					result[id] = parsed
				else:
					push_warning("DataManager: JSON 解析失败 %s%s" % [dir_path, file_name])
			elif file_name.ends_with(".tres"):
				var res: Resource = load(dir_path + file_name)
				if res != null:
					result[id] = res
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
