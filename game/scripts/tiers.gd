class_name Tiers
## Theme data for the 11 merge tiers. Palettes are swappable; sizes and names are shared.

const NAMES := ["Pip", "Bean", "Bun", "Dumpling", "Pudding", "Melon", "Boulder", "Cloud", "Moon", "Planet", "Sun"]
const RADII := [18.0, 26.0, 34.0, 44.0, 54.0, 66.0, 78.0, 92.0, 106.0, 122.0, 140.0]

const THEME_ORDER := ["classic", "candy", "neon"]
const THEMES := {
	"classic": {"name": "Classic", "unlock": 0, "bg": Color(0.08, 0.09, 0.14), "colors": [
		Color("#ff6b6b"), Color("#ffa94d"), Color("#ffd43b"), Color("#a9e34b"), Color("#51cf66"), Color("#38d9a9"),
		Color("#4dabf7"), Color("#748ffc"), Color("#da77f2"), Color("#f783ac"), Color("#ffe066")]},
	"candy": {"name": "Candy", "unlock": 3, "bg": Color(0.16, 0.08, 0.16), "colors": [
		Color("#ff8fab"), Color("#ffb3c6"), Color("#ffe5ec"), Color("#cdb4db"), Color("#bde0fe"), Color("#a2d2ff"),
		Color("#ffafcc"), Color("#f4acb7"), Color("#9d8189"), Color("#d8e2dc"), Color("#fff1a8")]},
	"neon": {"name": "Neon", "unlock": 7, "bg": Color(0.02, 0.02, 0.05), "colors": [
		Color("#ff2e63"), Color("#ff7b00"), Color("#f9f871"), Color("#7cff01"), Color("#00f5d4"), Color("#00bbf9"),
		Color("#4361ee"), Color("#9b5de5"), Color("#f15bb5"), Color("#fee440"), Color("#ffffff")]},
}

static var theme := "classic"


static func count() -> int:
	return RADII.size()


static func radius(tier: int) -> float:
	return RADII[tier]


static func color(tier: int) -> Color:
	return THEMES[theme]["colors"][tier]


static func background() -> Color:
	return THEMES[theme]["bg"]


static func tier_name(tier: int) -> String:
	return NAMES[tier]


## Points for merging two pieces of this tier (triangular numbers: 1, 3, 6, 10, ...).
static func merge_score(tier: int) -> int:
	return (tier + 1) * (tier + 2) / 2


## Draws one piece (glossy body plus face) on any CanvasItem, centered on its origin.
static func draw_piece(ci: CanvasItem, tier: int, r: float) -> void:
	var c := color(tier)
	ci.draw_circle(Vector2.ZERO, r, c)
	ci.draw_arc(Vector2.ZERO, r - 1.5, 0.0, TAU, 48, c.darkened(0.35), 3.0, true)
	# Wet highlight so the piece reads as a soft jelly blob.
	ci.draw_circle(Vector2(-r * 0.38, -r * 0.42), r * 0.17, Color(1, 1, 1, 0.32))
	ci.draw_circle(Vector2(-r * 0.22, -r * 0.58), r * 0.07, Color(1, 1, 1, 0.4))
	# Face
	var ink := Color(0.12, 0.1, 0.16)
	var eye_r := maxf(2.0, r * 0.09)
	ci.draw_circle(Vector2(-r * 0.32, -r * 0.12), eye_r, ink)
	ci.draw_circle(Vector2(r * 0.32, -r * 0.12), eye_r, ink)
	ci.draw_arc(Vector2(0.0, r * 0.12), r * 0.32, deg_to_rad(25.0), deg_to_rad(155.0), 16, ink, maxf(1.5, r * 0.05), true)
	# Cheeks
	var blush := Color(1.0, 0.5, 0.5, 0.35)
	ci.draw_circle(Vector2(-r * 0.5, r * 0.18), r * 0.11, blush)
	ci.draw_circle(Vector2(r * 0.5, r * 0.18), r * 0.11, blush)
