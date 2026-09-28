extends Label
## Shows which version of the game this is.

const SETTING := "application/config/version"
## What the version is before anything has been released.
const UNRELEASED := "0.0.0"


func _ready() -> void:
	text = describe(str(ProjectSettings.get_setting(SETTING, "")))


## The version as it is shown: "v0.1.0". A game that has never been
## released says so, since v0.0.0 looks like a release and is not one.
static func describe(version: String) -> String:
	if version.is_empty() or version == UNRELEASED:
		return "unreleased"
	return "v%s" % [version]
