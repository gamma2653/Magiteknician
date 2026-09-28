class_name DuelistPanel
extends PanelContainer
## Shows one duelist's health, ward and chi, and keeps them up to date.

const HURT_COLOR := Color(1.0, 0.45, 0.45)
const REFUSED_COLOR := Color(1.0, 0.35, 0.35)
const FLASH_SECONDS := 0.3

@onready var title: Label = %Name
@onready var subtitle: Label = %Subtitle
@onready var health_bar: ProgressBar = %Health
@onready var health_text: Label = %HealthText
@onready var ward_bar: ProgressBar = %Ward
@onready var chi_bar: ProgressBar = %Chi
@onready var chi_text: Label = %ChiText

var duelist: Duelist


## Shows `duelist_` from now on. `subtitle_` goes under their name.
func bind(duelist_: Duelist, subtitle_: String = "") -> void:
	if duelist != null:
		duelist.health_changed.disconnect(_on_health_changed)
		duelist.chi_changed.disconnect(_on_chi_changed)
		duelist.ward_changed.disconnect(_on_ward_changed)
		duelist.damaged.disconnect(_on_damaged)
	duelist = duelist_
	title.text = duelist.display_name
	subtitle.text = subtitle_
	duelist.health_changed.connect(_on_health_changed)
	duelist.chi_changed.connect(_on_chi_changed)
	duelist.ward_changed.connect(_on_ward_changed)
	duelist.damaged.connect(_on_damaged)
	_on_health_changed(duelist.health, duelist.max_health)
	_on_chi_changed(duelist.chi, duelist.max_chi)
	_on_ward_changed(duelist.ward)


## Flashes the chi bar, to say a spell could not be afforded.
func flash_chi() -> void:
	_flash(chi_bar, REFUSED_COLOR)


func _on_health_changed(health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	health_text.text = "%d / %d" % [ceili(health), roundi(max_health)]


func _on_chi_changed(chi: float, max_chi: float) -> void:
	chi_bar.max_value = max_chi
	chi_bar.value = chi
	chi_text.text = "%d chi" % [floori(chi)]


func _on_ward_changed(ward: float) -> void:
	# The bar is as long as the ward was when it was raised.
	if ward > ward_bar.max_value or ward_bar.value <= 0.0:
		ward_bar.max_value = maxf(ward, 1.0)
	ward_bar.value = ward
	ward_bar.modulate.a = 1.0 if ward > 0.0 else 0.0


func _on_damaged(_amount: float, _absorbed: float) -> void:
	_flash(self, HURT_COLOR)


func _flash(target: CanvasItem, color: Color) -> void:
	target.modulate = Color(color.r, color.g, color.b, target.modulate.a)
	var settle := target.create_tween()
	settle.tween_property(target, "modulate", Color(1, 1, 1, target.modulate.a), FLASH_SECONDS)
