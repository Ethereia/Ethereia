## 全局事件总线：跨系统通信统一走此单例的信号（doc 15 §6）
## 禁止把业务逻辑写在总线里，总线只声明信号
## 信号由其他系统发射/监听，分析器无法跨文件识别，屏蔽该类误报
@warning_ignore_start("unused_signal")
extends Node

# --- 游戏流程 ---
signal game_started
signal game_saved(slot: String)
signal game_loaded(slot: String)
signal returned_to_menu

# --- 时间系统（阶段8接入月结算调度） ---
signal month_changed(year: int, month: int)
signal season_changed(year: int, season: int)
signal year_changed(year: int)

# --- 角色与修仙（阶段5填充细节） ---
signal player_stats_changed
signal player_died
signal realm_breakthrough_success(new_realm_index: int)
signal realm_breakthrough_failed(new_realm_index: int)

# --- 世界状态（阶段7事件系统的触发条件来源） ---
signal world_state_changed(key: String, value: Variant)
signal faction_relation_changed(faction_a: String, faction_b: String, score: int)

@warning_ignore_restore("unused_signal")
