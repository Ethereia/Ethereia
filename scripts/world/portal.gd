## 传送门（阶段3）：Area2D，玩家踏入 → RegionScene.portal_entered → WorldManager 切区域
## armed 状态防重入：由 RegionScene 统一管理（本类只提供状态接口，不自行连接信号）
extends Area2D

@export var target_region := ""
@export var entry_location := ""

var _armed := true


func is_armed() -> bool:
	return _armed


func disarm() -> void:
	_armed = false


func rearm() -> void:
	_armed = true
