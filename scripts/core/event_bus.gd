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

# --- 世界与生态（阶段3） ---
signal region_entered(region_id: String)
signal enemy_died(enemy_id: String, region_id: String)
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)

# --- 交互与对话（阶段3） ---
signal npc_interacted(npc_id: String, dialogue_id: String)
signal dialogue_finished(npc_id: String)
signal dialogue_choice_made(source_id: String, choice_index: int)  # 阶段7：对话/事件选项落地（source_id = dlg_/event_ id）

# --- 任务（阶段7完善，阶段3最小推进） ---
signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_progress_changed(quest_id: String)

# --- 修仙（阶段5） ---
signal cultivation_state_changed  # 境界/经验/功法变化，UI 统一刷新

# --- 宗门（阶段6） ---
signal sect_state_changed  # 驻地/建筑/弟子变化，UI 统一刷新

@warning_ignore_restore("unused_signal")
