class_name TurnManager
extends Node
## Tracks the current turn and resolves end-turn requests after a cancellable
## real-time countdown. Future ship travel and research can react to turn_advanced.

signal end_turn_started(seconds_left: float)
signal end_turn_countdown_changed(seconds_left: float)
signal end_turn_cancelled
signal turn_advanced(turn: int)

const DEFAULT_END_TURN_SECONDS := 5.0

@export var end_turn_seconds := DEFAULT_END_TURN_SECONDS

var current_turn: int = 1

var _ending_turn := false
var _seconds_remaining := 0.0


func _process(delta: float) -> void:
	if not _ending_turn:
		return

	_seconds_remaining = maxf(0.0, _seconds_remaining - delta)
	end_turn_countdown_changed.emit(_seconds_remaining)
	if _seconds_remaining <= 0.0:
		advance_turn()


func start_end_turn() -> bool:
	if _ending_turn:
		return false

	_ending_turn = true
	_seconds_remaining = maxf(0.0, end_turn_seconds)
	end_turn_started.emit(_seconds_remaining)
	end_turn_countdown_changed.emit(_seconds_remaining)
	return true


func cancel_end_turn() -> bool:
	if not _ending_turn:
		return false

	_ending_turn = false
	_seconds_remaining = 0.0
	end_turn_cancelled.emit()
	return true


func advance_turn() -> void:
	_ending_turn = false
	_seconds_remaining = 0.0
	current_turn += 1
	turn_advanced.emit(current_turn)


func is_ending_turn() -> bool:
	return _ending_turn


func seconds_remaining() -> float:
	return _seconds_remaining
