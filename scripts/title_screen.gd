class_name TitleScreen
extends Control
## Title screen. Shows the title art, plays the title theme, and offers the
## main menu. Only New Game, Credits, and Quit are implemented in this slice;
## Load and Options arrive later.

signal new_game_requested

@onready var background: TextureRect = %Background
@onready var music_player: AudioStreamPlayer = %MusicPlayer
@onready var new_game_button: Button = %NewGameButton
@onready var load_button: Button = %LoadButton
@onready var options_button: Button = %OptionsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton
@onready var credits_backdrop: ColorRect = %CreditsBackdrop
@onready var credits_panel: PanelContainer = %CreditsPanel
@onready var credits_close_button: Button = %CreditsCloseButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_unavailable_pressed)
	options_button.pressed.connect(_on_unavailable_pressed)
	credits_button.pressed.connect(_open_credits)
	quit_button.pressed.connect(_on_quit_pressed)
	credits_close_button.pressed.connect(_hide_credits)
	credits_backdrop.gui_input.connect(_on_credits_backdrop_input)
	load_button.disabled = true
	load_button.tooltip_text = "Loading saved games will be implemented later"
	options_button.disabled = true
	options_button.tooltip_text = "Options will be implemented later"
	_hide_credits()
	_start_music()
	new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.is_action_pressed("ui_cancel")
	):
		if credits_panel.visible:
			_hide_credits()
			get_viewport().set_input_as_handled()


func _start_music() -> void:
	if music_player.stream == null:
		return
	var mp3 := music_player.stream as AudioStreamMP3
	if mp3 != null:
		mp3.loop = true
	music_player.volume_db = -10.0
	music_player.play()


func _on_new_game_pressed() -> void:
	music_player.stop()
	new_game_requested.emit()
	get_tree().change_scene_to_file("res://scenes/stellar_view.tscn")


func _on_unavailable_pressed() -> void:
	pass


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_credits() -> void:
	credits_backdrop.visible = true
	credits_panel.visible = true
	credits_close_button.grab_focus()


func _hide_credits() -> void:
	credits_backdrop.visible = false
	credits_panel.visible = false
	new_game_button.grab_focus()


func _on_credits_backdrop_input(event: InputEvent) -> void:
	if (
		credits_panel.visible
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_hide_credits()
