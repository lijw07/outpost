extends RefCounted
## Creator choices are cosmetic; equipment is a separate world-acquisition layer.
const VERSION := 1
const OPTIONS := {
	"sex":["male","female"],
	"skin":["porcelain","fair","warm","tan","brown","deep"],
	"hair":["crop","bob","ponytail","curls","bald"],
	"hair_color":["black","brown","chestnut","blonde","ginger","silver","blue","pink"],
	"eye_color":["brown","blue","green","hazel","gray","amber"],
	"top":["tee","sweatshirt","jacket"],
	"top_color":["navy","red","green","cream","gray","black","blue","purple"],
	"pants":["jeans","chinos","shorts"],
	"pants_color":["navy","black","gray","khaki","brown","blue"],
	"shoes":["sneakers","high_tops","loafers"],
	"shoes_color":["cream","black","brown","red","blue"]
}
const COLORS := {
	"black":"302e32","brown":"62452f","chestnut":"895237","blonde":"d0ae65","ginger":"bd653e","silver":"b0b2b2","blue":"527fac","pink":"b97591",
	"green":"657d54","hazel":"8a853d","gray":"7d8685","amber":"d89c4b",
	"navy":"3f526b","red":"9e4f46","cream":"d4cbb0","purple":"766081","khaki":"9e9269"
}
const SKIN_COLORS := {"porcelain":"f2cfb2","fair":"deb18e","warm":"cc976d","tan":"b77f54","brown":"8c5d42","deep":"593e32"}
const LABELS := {"sex":"SEX","skin":"SKIN TONE","hair":"HAIR STYLE","hair_color":"HAIR COLOR","eye_color":"EYE COLOR","top":"TOP","top_color":"TOP COLOR","pants":"PANTS","pants_color":"PANTS COLOR","shoes":"SHOES","shoes_color":"SHOE COLOR"}
const WORLD_EQUIPMENT := {
	"cap":{"slot":"hat","set":"civilian","acquisition":"world"},
	"helmet":{"slot":"hat","set":"military","acquisition":"world"},
	"backpack":{"slot":"bag","set":"civilian","acquisition":"world"},
	"rucksack":{"slot":"bag","set":"military","acquisition":"world"},
	"plate_carrier":{"slot":"armor","set":"military","acquisition":"world"},
	"field_jacket":{"slot":"outer","set":"military","acquisition":"world"},
	"cargo_pants":{"slot":"legs","set":"military","acquisition":"world"},
	"combat_boots":{"slot":"feet","set":"military","acquisition":"world"},
	"ghillie_hood":{"slot":"hat","set":"ghillie","acquisition":"world"},
	"ghillie_jacket":{"slot":"outer","set":"ghillie","acquisition":"world"},
	"ghillie_pants":{"slot":"legs","set":"ghillie","acquisition":"world"}
}

static func defaults() -> Dictionary:
	return {"version":VERSION,"sex":"male","skin":"warm","hair":"crop","hair_color":"brown","eye_color":"brown","top":"tee","top_color":"navy","pants":"jeans","pants_color":"navy","shoes":"sneakers","shoes_color":"cream"}

static func sanitize(value: Variant) -> Dictionary:
	var result := defaults()
	if not value is Dictionary:
		return result
	for key: String in OPTIONS:
		if value.get(key) in OPTIONS[key]:
			result[key] = value[key]
	return result

static func equipment(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for item: String in WORLD_EQUIPMENT:
			var slot: String = WORLD_EQUIPMENT[item].slot
			if value.get(slot) == item:
				result[slot] = item
	return result

static func color(key: String, skin := false) -> Color:
	return Color((SKIN_COLORS if skin else COLORS).get(key,"8a887d"))
