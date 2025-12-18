extends Control

@export var level_btn_scene: PackedScene
@export_file("*.tscn") var all_levels: Array[String]

@onready var grid = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var post_rect: ColorRect = $"PostProcessLayer/ColorRect"
@onready var post_mat: ShaderMaterial = post_rect.material as ShaderMaterial

var _transitioning := false

func _ready() -> void:
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if post_mat:
		post_mat.set_shader_parameter("progress", 0.0)

	for i in range(all_levels.size()):
		var path := all_levels[i]
		if path == "":
			continue

		var btn = level_btn_scene.instantiate()
		btn.get_node("Label").text = "Level " + str(i + 1)
		btn.level_path = path

		btn.level_chosen.connect(_on_level_pressed)

		grid.add_child(btn)

func _set_progress(v: float) -> void:
	if post_mat:
		post_mat.set_shader_parameter("progress", v)

func _on_level_pressed(level_path: String) -> void:
	if _transitioning or level_path == "":
		return
	_transitioning = true

	for c in grid.get_children():
		if c is BaseButton:
			c.disabled = true

	var target := 0.5
	var duration := 2

	if post_mat:
		post_mat.set_shader_parameter("progress", 0.0)
		var t := create_tween()
		t.tween_method(_set_progress, 0.0, target, duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await t.finished

	get_tree().change_scene_to_file(level_path)
