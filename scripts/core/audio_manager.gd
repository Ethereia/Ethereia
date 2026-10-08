## 音频管理器：BGM/SFX 播放入口（阶段0骨架）
## 资源命名见 doc 13 §9；动态音乐系统（分层/交叉淡化）按 doc 14 §3 在阶段10实现
extends Node

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_POOL_SIZE := 8

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_bgm: String = ""

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)

func play_bgm(file_name: String) -> void:
	if _current_bgm == file_name:
		return
	var stream: AudioStream = load(MUSIC_DIR + file_name)
	if stream == null:
		push_warning("AudioManager: 找不到 BGM %s" % (MUSIC_DIR + file_name))
		return
	_current_bgm = file_name
	_bgm_player.stream = stream
	_bgm_player.play()

func stop_bgm() -> void:
	_current_bgm = ""
	_bgm_player.stop()

func play_sfx(file_name: String) -> void:
	var stream: AudioStream = load(SFX_DIR + file_name)
	if stream == null:
		push_warning("AudioManager: 找不到 SFX %s" % (SFX_DIR + file_name))
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	push_warning("AudioManager: SFX 池已满，丢弃 %s" % file_name)
