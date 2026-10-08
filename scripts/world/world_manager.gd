## 世界管理器（阶段3）：区域生命周期 + 切换 + 接管存档 world_state 段
## Player 为常驻兄弟节点：切区域只移动位置不重建；读档路径不定位玩家（Player 自己回填，顺序解耦）
extends Node

const REGION_SCENES := {
	"region_qingshi_town": preload("res://scenes/world/QingshiTown.tscn"),
	"region_hei_feng_ling": preload("res://scenes/world/HeiFengLing.tscn"),
}
const DEFAULT_REGION := "region_qingshi_town"

var current_region_id := ""
var _regions_state: Dictionary = {}  # {rid: {"dead": [key], "harvested": [key]}}
var _portal_cooldown := 0.0  # 切区域后的传送门冷却，防止落点在门内引发乒乓切换

@onready var _current_region: RegionScene = null


func _process(delta: float) -> void:
	_portal_cooldown = maxf(0.0, _portal_cooldown - delta)


func _ready() -> void:
	add_to_group("savable")
	add_to_group("world_manager")  # Player 存档时经此组查 current_region
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_boss_died)
	switch_region(DEFAULT_REGION, "", true)


## Boss 击杀剧情（垂直切片 Step 12 伏笔）：world_state 标记 + 冥门提示
func _on_boss_died(enemy_id: String, _region_id: String) -> void:
	if enemy_id != "char_hei_feng_yao_lang_wang":
		return
	_regions_state["boss_yao_lang_wang_killed"] = true
	# 延迟弹提示：等掉落生成完、战斗余波平息
	get_tree().create_timer(1.5).timeout.connect(_show_nemesis_notice)


func _show_nemesis_notice() -> void:
	var dialogs := get_tree().get_nodes_in_group("dialogue_ui")
	if dialogs.is_empty():
		return
	dialogs[0].show_notice("妖狼王倒下的瞬间，你看见它腹下的黑色印记渗出幽光——灵脉下方，仿佛有什么东西正隔着极其遥远的距离，与那道光共鸣……\n\n（垂直切片 Step 12 · 冥门伏笔）")


## 玩家死亡占位处理：短暂停顿后半血回当前区域出生点（阶段5 修仙死亡惩罚另做）
func _on_player_died() -> void:
	get_tree().create_timer(1.0).timeout.connect(_revive_player_at_spawn)


func _revive_player_at_spawn() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	player.stats.revive(0.5)
	player.global_position = _current_region.player_spawn if _current_region != null else Vector2.ZERO
	print("[WorldManager] 玩家已在出生点复活（半血）")


## 切换区域：free 旧区域 → 实例化新区域 → 定位玩家 → 广播
## teleport=false 用于读档路径（Player.load_save_state 自己回填位置）
func switch_region(region_id: String, entry_location: String = "", teleport: bool = true) -> void:
	if region_id == current_region_id and _current_region != null:
		return
	var old := _current_region
	_current_region = null
	current_region_id = ""
	if old != null:
		old.queue_free()

	var scene: PackedScene = REGION_SCENES.get(region_id)
	if scene == null:
		push_error("[WorldManager] 未知区域 %s" % region_id)
		return
	var state: Dictionary = _regions_state.get(region_id, {"dead": [], "harvested": []})
	var region := scene.instantiate() as RegionScene
	add_child(region)
	region.setup(DataManager.get_entry("regions", region_id), state.get("dead", []), state.get("harvested", []))
	region.portal_entered.connect(_on_portal_entered)
	_current_region = region
	current_region_id = region_id

	if teleport:
		_teleport_player(entry_location)
	EventBus.region_entered.emit(region_id)


func _teleport_player(entry_location: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var target := _current_region.player_spawn
	if not entry_location.is_empty():
		for loc: Dictionary in _current_region.region_data.locations:
			if String(loc["id"]) == entry_location:
				target = Vector2(Vector2i(loc["position"])) * 64
				break
	player.global_position = target


func _on_portal_entered(target_region: String, entry_location: String) -> void:
	if _portal_cooldown > 0.0:
		return
	_portal_cooldown = 0.6
	print("[WorldManager] 穿过传送门 → %s（入口 %s）" % [target_region, entry_location])
	# portal 回调发生在物理 flushing 期间：切区域会增删物理体，必须 deferred
	call_deferred("_deferred_switch_region", target_region, entry_location)


func _deferred_switch_region(target_region: String, entry_location: String) -> void:
	switch_region(target_region, entry_location, true)


## 敌人死亡记录（QuestManager/区域重建共用）
func record_enemy_death(enemy_key: String) -> void:
	var state: Dictionary = _regions_state.get(current_region_id, {"dead": [], "harvested": []})
	if not enemy_key in state["dead"]:
		state["dead"].append(enemy_key)
	_regions_state[current_region_id] = state


## 资源采集记录
func record_harvest(node_key: String) -> void:
	var state: Dictionary = _regions_state.get(current_region_id, {"dead": [], "harvested": []})
	if not node_key in state["harvested"]:
		state["harvested"].append(node_key)
	_regions_state[current_region_id] = state


## 世界标志（Phase 7 事件/剧情条件来源）：顶层键，随 world_state 段自动持久化
func set_world_flag(key: String, value: Variant) -> void:
	_regions_state[key] = value
	EventBus.world_state_changed.emit(key, value)


func get_world_flag(key: String) -> Variant:
	return _regions_state.get(key)


func has_world_flag(key: String) -> bool:
	return _regions_state.has(key)


# --- 存档（world_state 段） ---

func get_save_section() -> String:
	return "world_state"


func get_save_state() -> Dictionary:
	return {"current_region": current_region_id, "regions": _regions_state.duplicate(true)}


func load_save_state(state: Dictionary) -> void:
	_regions_state = state.get("regions", {})
	var region_id := String(state.get("current_region", DEFAULT_REGION))
	# 读档路径：重建区域但不定位玩家（Player.load_save_state 自己回填，与遍历顺序无关）
	current_region_id = ""  # 强制重建
	switch_region(region_id, "", false)
