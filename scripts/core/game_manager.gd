extends Node

signal coins_changed(total: int)
signal progression_changed(level: int, experience: int, next_level_experience: int)

const SAVE_PATH: String = "user://desk_apocalypse_save.json"

var coins:int = 0
var level: int = 1
var experience: int = 0
var next_level_experience: int = 30
var weapon_level: int = 1
var weapon_bonus_damage: int = 0

func add_coin(amount: int) -> void:
    coins += amount
    coins_changed.emit(coins)

func add_experience(amount: int) -> void:
    experience += maxi(amount, 0)
    while experience >= next_level_experience:
        experience -= next_level_experience
        level += 1
        weapon_level += 1
        weapon_bonus_damage += 5
        next_level_experience = ceili(next_level_experience * 1.5)
    progression_changed.emit(level, experience, next_level_experience)

func reset_run() -> void:
    coins = 0
    level = 1
    experience = 0
    next_level_experience = 30
    weapon_level = 1
    weapon_bonus_damage = 0
    coins_changed.emit(coins)
    progression_changed.emit(level, experience, next_level_experience)

func save_game() -> bool:
    var payload := {
        "coins": coins,
        "level": level,
        "experience": experience,
        "next_level_experience": next_level_experience,
        "weapon_level": weapon_level,
        "weapon_bonus_damage": weapon_bonus_damage,
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(payload))
    return true

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return false
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return false
    coins = int(parsed.get("coins", coins))
    level = maxi(int(parsed.get("level", level)), 1)
    experience = maxi(int(parsed.get("experience", experience)), 0)
    next_level_experience = maxi(int(parsed.get("next_level_experience", next_level_experience)), 1)
    weapon_level = maxi(int(parsed.get("weapon_level", weapon_level)), 1)
    weapon_bonus_damage = maxi(int(parsed.get("weapon_bonus_damage", weapon_bonus_damage)), 0)
    coins_changed.emit(coins)
    progression_changed.emit(level, experience, next_level_experience)
    return true
