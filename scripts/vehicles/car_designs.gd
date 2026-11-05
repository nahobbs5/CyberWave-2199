class_name CarDesigns
extends RefCounted
## Shapes of the eight procedural car models (GDD 5.1), after the roster
## concept art. CarModelBuilder reads these.
##
## body:  stations front (-Z) to rear, [z, half_width, bottom_y, top_y, top_fraction]
##        (top_fraction = how much of the width the flat top keeps).
## cabin: [z, roof_half_width, roof_y]; the base follows the body top. The
##        first and last stations sit on the body, so the ends slope into
##        windscreens. open_cabin = only the windscreen (roadster, prototype).
## parts: [kind, material, size, position, rotation_degrees]
##        kinds: box, wedge, cyl (size = radius, length, segments), and
##        mirror_* versions that also add the part mirrored across X.
##        materials: Paint, Glass, Trim, Chrome, Lights (accent), Tail.
## accent: the car's signature light colour. paint: default body colour.
## Optional: plate_anchor (Transform3D), decal (right-side position; mirrored).

const DESIGNS := {
	# Classic muscle silhouette: long hood, fastback, full-width light bars.
	"v8_specter": {
		"paint": Color(0.06, 0.06, 0.08),
		"accent": Color(1.0, 0.55, 0.1),
		"body": [
			[-2.3, 0.84, -0.16, 0.10, 0.82],
			[-2.15, 0.94, -0.22, 0.16, 0.84],
			[-1.4, 0.97, -0.24, 0.19, 0.84],
			[-0.3, 0.96, -0.24, 0.21, 0.82],
			[1.1, 1.0, -0.24, 0.24, 0.82],
			[2.05, 0.98, -0.21, 0.27, 0.86],
			[2.3, 0.93, -0.15, 0.26, 0.86],
		],
		"cabin": [[-0.75, 0.76, 0.205], [-0.1, 0.62, 0.66], [0.6, 0.62, 0.66], [1.95, 0.72, 0.268]],
		"parts": [
			["box", "Trim", Vector3(1.5, 0.16, 0.06), Vector3(0, -0.04, -2.31)],
			["box", "Lights", Vector3(1.55, 0.035, 0.04), Vector3(0, 0.065, -2.325)],
			["mirror_box", "Lights", Vector3(0.28, 0.06, 0.04), Vector3(0.55, -0.03, -2.33)],
			["box", "Chrome", Vector3(1.72, 0.05, 0.14), Vector3(0, -0.16, -2.3)],
			["box", "Chrome", Vector3(1.8, 0.05, 0.12), Vector3(0, -0.14, 2.31)],
			["box", "Tail", Vector3(1.7, 0.07, 0.04), Vector3(0, 0.13, 2.32)],
			["box", "Paint", Vector3(1.6, 0.05, 0.26), Vector3(0, 0.3, 2.2), Vector3(-8, 0, 0)],
			["box", "Trim", Vector3(0.5, 0.08, 0.9), Vector3(0, 0.215, -1.3)],
			["mirror_box", "Lights", Vector3(0.02, 0.03, 1.8), Vector3(0.975, 0.02, 0.2)],
		],
	},
	# 1980s wedge: knife-edge nose rising to a squared tail, pink light lines.
	"aurora_gt": {
		"paint": Color(0.7, 0.72, 0.76),
		"accent": Color(1.0, 0.25, 0.85),
		"body": [
			[-2.25, 0.82, -0.15, -0.02, 0.9],
			[-1.9, 0.93, -0.2, 0.04, 0.9],
			[-0.8, 0.98, -0.22, 0.13, 0.88],
			[0.6, 0.99, -0.23, 0.2, 0.86],
			[1.8, 0.99, -0.22, 0.26, 0.86],
			[2.25, 0.95, -0.17, 0.27, 0.88],
		],
		"cabin": [[-0.95, 0.8, 0.12], [-0.15, 0.6, 0.6], [0.55, 0.6, 0.6], [1.6, 0.7, 0.258]],
		"parts": [
			["box", "Lights", Vector3(1.5, 0.03, 0.04), Vector3(0, -0.03, -2.26)],
			["mirror_box", "Lights", Vector3(0.02, 0.03, 2.4), Vector3(0.99, -0.06, -0.1)],
			["box", "Trim", Vector3(1.2, 0.03, 0.08), Vector3(0, 0.255, 1.7)],
			["box", "Trim", Vector3(1.2, 0.03, 0.08), Vector3(0, 0.265, 1.88)],
			["box", "Trim", Vector3(1.2, 0.03, 0.08), Vector3(0, 0.272, 2.05)],
			["box", "Tail", Vector3(1.75, 0.06, 0.04), Vector3(0, 0.14, 2.26)],
			["box", "Paint", Vector3(1.75, 0.035, 0.2), Vector3(0, 0.36, 2.15)],
			["mirror_box", "Trim", Vector3(0.05, 0.08, 0.1), Vector3(0.7, 0.31, 2.15)],
		],
	},
	# Corporate opulence: tall, upright, a towering chrome grille, gold lights.
	"empyrean_s": {
		"paint": Color(0.05, 0.04, 0.05),
		"accent": Color(1.0, 0.75, 0.3),
		"body": [
			[-2.45, 0.9, -0.2, 0.2, 0.9],
			[-2.3, 0.97, -0.24, 0.3, 0.9],
			[-0.5, 1.0, -0.25, 0.32, 0.9],
			[1.6, 1.0, -0.25, 0.33, 0.9],
			[2.3, 0.97, -0.23, 0.3, 0.9],
			[2.45, 0.92, -0.2, 0.27, 0.92],
		],
		"cabin": [[-0.55, 0.86, 0.31], [-0.2, 0.72, 0.92], [1.35, 0.72, 0.92], [1.85, 0.84, 0.33]],
		"parts": [
			["box", "Chrome", Vector3(0.62, 0.42, 0.07), Vector3(0, 0.02, -2.47)],
			["box", "Trim", Vector3(0.5, 0.34, 0.02), Vector3(0, 0.02, -2.51)],
			["mirror_box", "Lights", Vector3(0.34, 0.05, 0.04), Vector3(0.62, 0.15, -2.46)],
			["box", "Lights", Vector3(1.6, 0.03, 0.04), Vector3(0, -0.15, -2.46)],
			["box", "Chrome", Vector3(0.04, 0.12, 0.08), Vector3(0, 0.37, -2.33)],
			["box", "Chrome", Vector3(1.85, 0.06, 0.14), Vector3(0, -0.2, -2.45)],
			["box", "Chrome", Vector3(1.85, 0.06, 0.14), Vector3(0, -0.18, 2.45)],
			["mirror_box", "Tail", Vector3(0.12, 0.3, 0.04), Vector3(0.78, 0.07, 2.46)],
			["mirror_box", "Chrome", Vector3(0.015, 0.03, 4.4), Vector3(1.0, 0.08, 0.0)],
		],
	},
	# Low, angular supercar with a cab-forward canopy and a big rear wing.
	"nexus_x": {
		"paint": Color(0.24, 0.27, 0.31),
		"accent": Color(0.0, 0.9, 1.0),
		"body": [
			[-2.25, 0.86, -0.15, -0.05, 0.85],
			[-1.8, 0.98, -0.2, 0.02, 0.85],
			[-0.6, 1.02, -0.22, 0.12, 0.8],
			[0.8, 1.03, -0.22, 0.17, 0.78],
			[1.8, 1.02, -0.21, 0.2, 0.82],
			[2.25, 0.97, -0.17, 0.17, 0.86],
		],
		"cabin": [[-1.1, 0.8, 0.065], [-0.3, 0.55, 0.5], [0.45, 0.55, 0.5], [1.7, 0.62, 0.198]],
		"parts": [
			["mirror_box", "Lights", Vector3(0.55, 0.03, 0.04), Vector3(0.48, -0.05, -2.2), Vector3(0, -14, 0)],
			["mirror_box", "Trim", Vector3(0.05, 0.18, 0.7), Vector3(1.02, -0.03, 0.5)],
			["mirror_box", "Lights", Vector3(0.02, 0.02, 0.7), Vector3(1.05, 0.07, 0.5)],
			["box", "Trim", Vector3(1.95, 0.05, 0.42), Vector3(0, 0.56, 2.0), Vector3(-6, 0, 0)],
			["mirror_box", "Trim", Vector3(0.05, 0.38, 0.12), Vector3(0.5, 0.36, 2.0)],
			["mirror_box", "Lights", Vector3(0.03, 0.2, 0.46), Vector3(0.98, 0.56, 2.0)],
			["box", "Tail", Vector3(1.6, 0.04, 0.04), Vector3(0, 0.1, 2.26)],
			["box", "Trim", Vector3(1.5, 0.08, 0.2), Vector3(0, -0.16, 2.2)],
		],
	},
	# Vintage roadster: curvy fenders, open cockpit, round lamps and chrome.
	"riviera_88": {
		"paint": Color(0.42, 0.6, 0.62),
		"accent": Color(1.0, 0.85, 0.55),
		"open_cabin": true,
		"body": [
			[-2.2, 0.78, -0.13, 0.05, 0.7],
			[-1.95, 0.9, -0.2, 0.17, 0.72],
			[-1.4, 0.97, -0.22, 0.2, 0.62],
			[-0.7, 0.9, -0.22, 0.12, 0.78],
			[0.5, 0.92, -0.22, 0.13, 0.78],
			[1.35, 0.98, -0.22, 0.2, 0.62],
			[1.95, 0.92, -0.19, 0.17, 0.7],
			[2.2, 0.8, -0.13, 0.1, 0.75],
		],
		"cabin": [[-0.6, 0.66, 0.135], [-0.35, 0.6, 0.45], [-0.33, 0.6, 0.45]],
		"parts": [
			["box", "Trim", Vector3(1.3, 0.04, 1.25), Vector3(0, 0.135, 0.2)],
			["mirror_box", "Trim", Vector3(0.45, 0.32, 0.14), Vector3(0.33, 0.29, 0.55), Vector3(-12, 0, 0)],
			["mirror_cyl", "Trim", Vector3(0.11, 0.1, 10), Vector3(0.33, 0.5, 0.66)],
			["mirror_cyl", "Lights", Vector3(0.11, 0.06, 12), Vector3(0.6, 0.06, -2.1)],
			["cyl", "Chrome", Vector3(0.2, 0.05, 14), Vector3(0, -0.02, -2.21)],
			["cyl", "Trim", Vector3(0.16, 0.02, 14), Vector3(0, -0.02, -2.24)],
			["box", "Chrome", Vector3(1.6, 0.05, 0.1), Vector3(0, -0.13, -2.2)],
			["box", "Chrome", Vector3(1.6, 0.05, 0.1), Vector3(0, -0.12, 2.2)],
			["mirror_cyl", "Tail", Vector3(0.07, 0.05, 10), Vector3(0.58, 0.04, 2.19)],
			["mirror_box", "Chrome", Vector3(0.015, 0.025, 3.6), Vector3(0.93, 0.0, 0.0)],
		],
	},
	# Jet-age aero coupe: pointed nose, bubble canopy, tail fins, red jets.
	"orbiter": {
		"paint": Color(0.78, 0.8, 0.84),
		"accent": Color(1.0, 0.15, 0.2),
		"body": [
			[-2.35, 0.55, -0.08, 0.06, 0.7],
			[-2.05, 0.86, -0.18, 0.15, 0.75],
			[-0.9, 0.97, -0.22, 0.18, 0.75],
			[0.9, 0.97, -0.22, 0.18, 0.78],
			[1.9, 0.93, -0.2, 0.2, 0.8],
			[2.35, 0.82, -0.15, 0.18, 0.82],
		],
		"cabin": [[-0.8, 0.7, 0.175], [-0.4, 0.55, 0.48], [0.3, 0.42, 0.6], [0.9, 0.48, 0.52], [1.5, 0.64, 0.188]],
		"parts": [
			["mirror_wedge", "Paint", Vector3(0.05, 0.55, 0.9), Vector3(0.8, 0.42, 1.85)],
			["mirror_box", "Tail", Vector3(0.07, 0.05, 0.18), Vector3(0.8, 0.7, 2.24)],
			["mirror_cyl", "Tail", Vector3(0.11, 0.06, 12), Vector3(0.45, 0.02, 2.35)],
			["mirror_cyl", "Lights", Vector3(0.09, 0.05, 12), Vector3(0.55, 0.03, -2.1)],
			["cyl", "Trim", Vector3(0.12, 0.05, 12), Vector3(0, -0.01, -2.36)],
			["mirror_box", "Lights", Vector3(0.02, 0.025, 3.4), Vector3(0.975, -0.04, 0.0)],
			["box", "Chrome", Vector3(1.4, 0.04, 0.1), Vector3(0, -0.12, -2.22)],
		],
	},
	# Executive sedan with a racer's soul: boxy, four doors, slatted grille.
	"valkyrie_r": {
		"paint": Color(0.22, 0.2, 0.28),
		"accent": Color(0.75, 0.3, 1.0),
		"body": [
			[-2.35, 0.9, -0.2, 0.13, 0.88],
			[-2.15, 0.97, -0.24, 0.21, 0.88],
			[0.0, 0.99, -0.25, 0.24, 0.88],
			[2.05, 0.98, -0.24, 0.27, 0.88],
			[2.35, 0.94, -0.2, 0.25, 0.9],
		],
		"cabin": [[-1.0, 0.84, 0.215], [-0.35, 0.7, 0.76], [1.15, 0.7, 0.76], [1.8, 0.8, 0.27]],
		"parts": [
			["box", "Trim", Vector3(0.9, 0.2, 0.05), Vector3(0, -0.01, -2.37)],
			["box", "Lights", Vector3(0.03, 0.18, 0.03), Vector3(-0.32, -0.01, -2.4)],
			["box", "Lights", Vector3(0.03, 0.18, 0.03), Vector3(-0.16, -0.01, -2.4)],
			["box", "Lights", Vector3(0.03, 0.18, 0.03), Vector3(0.0, -0.01, -2.4)],
			["box", "Lights", Vector3(0.03, 0.18, 0.03), Vector3(0.16, -0.01, -2.4)],
			["box", "Lights", Vector3(0.03, 0.18, 0.03), Vector3(0.32, -0.01, -2.4)],
			["mirror_box", "Lights", Vector3(0.36, 0.04, 0.04), Vector3(0.64, 0.1, -2.37)],
			["box", "Paint", Vector3(1.7, 0.04, 0.28), Vector3(0, 0.42, 2.15)],
			["mirror_box", "Trim", Vector3(0.05, 0.14, 0.1), Vector3(0.6, 0.34, 2.15)],
			["box", "Tail", Vector3(1.75, 0.06, 0.04), Vector3(0, 0.13, 2.36)],
			["mirror_box", "Lights", Vector3(0.02, 0.025, 3.6), Vector3(0.995, -0.06, 0.0)],
		],
	},
	# Open-wheel prototype: narrow tub, sidepods, exposed wheels, big wings.
	"cipher_evo": {
		"paint": Color(0.6, 0.6, 0.63),
		"accent": Color(1.0, 0.5, 0.1),
		"open_cabin": true,
		"body": [
			[-2.3, 0.2, -0.1, 0.0, 0.9],
			[-1.6, 0.32, -0.16, 0.1, 0.85],
			[-0.5, 0.42, -0.2, 0.2, 0.8],
			[0.7, 0.48, -0.2, 0.26, 0.8],
			[1.7, 0.4, -0.18, 0.24, 0.85],
			[2.3, 0.28, -0.14, 0.16, 0.9],
		],
		"cabin": [[-0.75, 0.32, 0.19], [-0.5, 0.26, 0.38], [-0.49, 0.26, 0.38]],
		"plate_anchor": Transform3D(Basis.IDENTITY, Vector3(0.0, -0.04, 2.31)),
		"decal": Vector3(0.795, 0.0, 0.45), # on the sidepods
		"parts": [
			["mirror_box", "Paint", Vector3(0.36, 0.28, 1.4), Vector3(0.6, -0.04, 0.45)],
			["mirror_box", "Lights", Vector3(0.02, 0.03, 1.3), Vector3(0.785, 0.05, 0.45)],
			["box", "Trim", Vector3(2.0, 0.04, 0.35), Vector3(0, -0.18, -2.2)],
			["mirror_box", "Lights", Vector3(0.03, 0.14, 0.4), Vector3(1.0, -0.12, -2.2)],
			["box", "Trim", Vector3(1.8, 0.05, 0.45), Vector3(0, 0.72, 2.05), Vector3(-8, 0, 0)],
			["mirror_box", "Paint", Vector3(0.04, 0.42, 0.62), Vector3(0.9, 0.55, 2.05)],
			["mirror_box", "Lights", Vector3(0.045, 0.03, 0.62), Vector3(0.9, 0.77, 2.05)],
			["box", "Trim", Vector3(0.22, 0.36, 0.45), Vector3(0, 0.42, 0.45)],
			["wedge", "Paint", Vector3(0.36, 0.32, 1.1), Vector3(0, 0.38, 1.2), Vector3(0, 180, 0)],
			["cyl", "Trim", Vector3(0.13, 0.26, 10), Vector3(0, 0.33, 0.0), Vector3(90, 0, 0)],
			["mirror_box", "Trim", Vector3(0.5, 0.03, 0.06), Vector3(0.62, -0.08, -1.35)],
			["mirror_box", "Trim", Vector3(0.45, 0.03, 0.06), Vector3(0.62, -0.08, 1.35)],
			["box", "Tail", Vector3(0.3, 0.05, 0.04), Vector3(0, 0.05, 2.31)],
		],
	},
}


static func get_design(id: String) -> Dictionary:
	return DESIGNS.get(id, {})


static func has_design(id: String) -> bool:
	return DESIGNS.has(id)
