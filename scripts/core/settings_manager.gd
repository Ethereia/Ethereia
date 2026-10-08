## 设置管理器：音量/显示设置持久化到 user://settings.json
## 可访问性为硬性要求（doc 12）：音量独立调整、后续补按键重绑定
extends Node

const SETTINGS_PATH := "user://settings.json"

var settings: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"fullscreen": false,
}

func _ready() -> void:
	load_settings()

func set_setting(key: String, value: Variant) -> void:
	if settings.has(key):
		settings[key] = value

func save_settings() -> bool:
	var fa := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if fa == null:
		push_error("SettingsManager: 无法写入 %s" % SETTINGS_PATH)
		return false
	fa.store_string(JSON.stringify(settings, "\t"))
	fa.flush()
	fa.close()
	return true

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if parsed is Dictionary:
		for key: String in parsed:
			if settings.has(key):
				settings[key] = parsed[key]
	else:
		push_warning("SettingsManager: 设置文件解析失败，使用默认设置")
