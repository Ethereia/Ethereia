## 存档管理器：版本化 + 原子写入（doc 16）
## 原则：只存"状态"（id/数量/变量），不存静态定义
## 纪律：每个需要持久化的系统实现 get_save_state()/load_save_state() 并加入 "savable" 组，
##       并通过 get_save_section() 声明所属存档段（doc 29 §3 的 11 段标准结构）
extends Node

const SAVABLE_GROUP := "savable"
const SAVE_VERSION := 2

## 标准存档段结构（doc 16 §4 / doc 29 §3，ADR-007；v1.1 增 events 段——ADR-008）
const SAVE_SECTIONS: Array[String] = [
	"player_state", "cultivation_state", "inventory", "characters", "sect_state",
	"world_state", "quests", "events", "factions", "time_state", "settings",
]

const SAVE_DIR := "user://saves/"
const AUTOSAVE_SLOT := "autosave"
const QUICKSAVE_SLOT := "quicksave"

var _pending_data: Dictionary = {}
var _last_slot: String = ""

func save_game(slot: String) -> bool:
	var data := _collect_save_data()
	var path := SAVE_DIR + "slot_%s.json" % slot
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var tmp := path + ".tmp"
	var fa := FileAccess.open(tmp, FileAccess.WRITE)
	if fa == null:
		push_error("SaveManager: 无法写入临时存档 %s" % tmp)
		return false
	fa.store_string(JSON.stringify(data, "\t"))
	fa.flush()
	fa.close()
	# 旧档留一份备份（doc 16：自动保存至少留一份备份）
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("SaveManager: 原子替换失败 %s (错误码 %d)" % [path, err])
		return false
	_last_slot = slot
	EventBus.game_saved.emit(slot)
	return true

## 读取存档。apply=true 时立即推送给所有 savable 节点；
## apply=false 时缓存为待应用数据（用于"主菜单→继续"先切场景再应用的流程）
func load_game(slot: String, apply: bool = true) -> bool:
	var path := SAVE_DIR + "slot_%s.json" % slot
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: 存档不存在 %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("SaveManager: 存档损坏 %s" % path)
		return false
	var data := _migrate(parsed as Dictionary)
	_last_slot = slot
	if apply:
		_pending_data = data
		apply_pending_load()
	else:
		_pending_data = data
	return true

func apply_pending_load() -> void:
	if _pending_data.is_empty():
		return
	for node in get_tree().get_nodes_in_group(SAVABLE_GROUP):
		if not node.has_method("load_save_state"):
			continue
		var key := _section_key_of(node)
		if _pending_data.has(key):
			node.load_save_state(_pending_data[key])
	_pending_data = {}
	EventBus.game_loaded.emit(_last_slot)

func has_any_save() -> bool:
	return get_latest_slot() != ""

## 取最近修改的存档槽位（自动存档除外）
func get_latest_slot() -> String:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return ""
	var best_slot := ""
	var best_time := -1
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and file_name.begins_with("slot_"):
			var slot := file_name.trim_prefix("slot_").trim_suffix(".json")
			if slot == AUTOSAVE_SLOT or slot == QUICKSAVE_SLOT:
				file_name = dir.get_next()
				continue
			var mtime := FileAccess.get_modified_time(SAVE_DIR + file_name)
			if mtime > best_time:
				best_time = mtime
				best_slot = slot
		file_name = dir.get_next()
	dir.list_dir_end()
	return best_slot

## 取 savable 节点的存档段键：优先 get_save_section()，缺省回退节点名
static func _section_key_of(node: Node) -> String:
	var key := ""
	if node.has_method("get_save_section"):
		key = String(node.get_save_section())
	if key.is_empty() or not key in SAVE_SECTIONS:
		key = String(node.name)
	return key

func _collect_save_data() -> Dictionary:
	var data: Dictionary = {}
	for section in SAVE_SECTIONS:
		data[section] = {}
	for node in get_tree().get_nodes_in_group(SAVABLE_GROUP):
		if node.has_method("get_save_state"):
			var key := _section_key_of(node)
			data[key].merge(node.get_save_state(), true)
	data["save_version"] = SAVE_VERSION
	data["timestamp"] = Time.get_datetime_string_from_system(true, false)
	return data

## 版本迁移链（doc 16 §7）：数据结构变更时在此追加链式迁移函数
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_version", 0))
	while version < SAVE_VERSION:
		match version:
			0:
				data = _migrate_v0_to_v1(data)
				version = 1
			1:
				data = _migrate_v1_to_v2(data)
				version = 2
			_:
				push_error("SaveManager: 未知存档版本 %d，中止迁移" % version)
				break
	return data

func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	# 占位：为无版本号的极早期存档补上版本号
	data["save_version"] = 1
	return data

func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	# v1 的 sections{节点名} → v2 的 11 段标准结构（doc 29 §3）
	var sections: Dictionary = data.get("sections", {})
	data["time_state"] = sections.get("TimeManager", {})
	data["player_state"] = sections.get("Game", {})
	data.erase("sections")
	return data
