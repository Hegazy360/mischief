"""Colours for the art-hush cast (GDD 1.2 / 9.1). base/shade pairs: shade ~ base x 0.84, hue-shifted
warm for warm colours and toward blue for cool ones. Far-side limbs use shade as base and `deep` as shade."""

INK = "#1B2340"
WHITE = "#FFFFFF"

HUSH = dict(
	paint="#FFF6EA", paint_s="#EFDCCB", paint_d="#E0C8B6",   # face paint (white, warm)
	cheek="#FF9AA2",
	hair="#4A2C3E", hair_s="#33203A",                          # plum-black bob
	tear="#2B3566",                                           # painted teardrop (navy)
	navy="#2B3566", navy_s="#1F2750", navy_d="#182041",
	stripe="#F7F5F0", stripe_s="#D3D8E8",
	red="#E23B4E", red_s="#B82A3C", red_d="#96202F",           # beret + braces
	glove="#FFFFFF", glove_s="#D6DCEB", glove_far="#E3E7F1", glove_far_s="#C0C8DB",
	shoe="#3A3050", shoe_s="#2A2240", shoe_far="#2E2642", shoe_far_s="#221B35",
	lip="#E23B4E", mouth="#7A1F35", tongue="#FF7F8E", teeth="#FFFFFF",
	sweat="#8FD3F4", sweat_s="#5BB4E0",
	eye="#FFFFFF", eye_s="#E4E6F0",
	tomato="#E2402F", tomato_s="#B52D22", seed="#FFD36B", stalk="#3E9E36",
)

PIP = dict(
	skin="#F2C29B", skin_s="#DFA47C", skin_d="#C98C66",
	cheek="#FF9AA2", freckle="#C9795A",
	hair="#D9722B", hair_s="#B45A1E",                           # ginger tufts
	knit="#E23B4E", knit_s="#B82A3C", knit_l="#FF6B7B",         # red beanie
	jumper="#2E9C95", jumper_s="#217A75", cream="#FFF3D6", cream_s="#E6D3AE",   # teal / cream stripes
	denim="#3F5FA3", denim_s="#2F4A85", denim_d="#263C6E",
	mitten="#FFF3D6", mitten_s="#E2CFA8", mitten_far="#EADCB9", mitten_far_s="#CDB88F",
	cuff="#E23B4E", cuff_s="#B82A3C",
	shoe="#E23B4E", shoe_s="#B82A3C", shoe_far="#C43244", shoe_far_s="#9E2535", sole="#FFFFFF", sole_s="#D6DCEB",
	brow="#B45A1E",
)

CLARENCE = dict(
	yellow="#FFD23F", yellow_s="#E0A91A",
	comb="#E23B4E", comb_s="#B82A3C",
	beak="#FF8A1F", beak_s="#D96A08",
	eye="#FFFFFF",
)

FIGGIS = dict(
	hood="#3A3050", hood_s="#2A2240", inside="#1E1830",
	gold="#E8B33A", gold_s="#C08A1E",
	skin="#F4C9A8", skin_s="#DDA888", ear_in="#E89A8A",
	hair="#F1F3F8", hair_s="#C9CEDD",
	cardigan="#7F8C5A", cardigan_s="#626E44",
	card="#FFF6EA", card_s="#E8D7C0",
	glass="#DDF1FA",
)

STALLS = dict(fill="#2A1E3A")
