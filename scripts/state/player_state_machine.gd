extends RefCounted

signal state_changed(previous_state: int, current_state: int)

enum State {
	IDLE,
	MOVE,
	ATTACK,
	HIT,
	DEAD
}

var current_state := State.IDLE

func transition_to(next_state: int) -> void:
	if current_state == next_state:
		return

	var previous_state := current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)
