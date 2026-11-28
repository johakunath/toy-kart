class_name Items extends RefCounted
## The friendly item set and who gets what. Nothing here hurts: the worst any item does is a
## short, funny wobble, and it never targets a kid-mode player.
##   TURBO         a boost, kept until the use button (kid mode: fires by itself after a second)
##   SUPERSTAR     a long boost; bumps and tickles cannot touch you meanwhile
##   BUBBLE        a shield that pops one tickle
##   SPRING        the kart jumps (with a trick and a landing boost)
##   TICKLE        a pink bubble flies to the kart ahead and makes it wobble (never to a kid)
##   TRIPLE_TURBO  three turbos, one per press (for karts at the back)

enum { NONE, TURBO, SUPERSTAR, BUBBLE, SPRING, TICKLE, TRIPLE_TURBO }

const ICONS := {
	TURBO: "item_turbo", SUPERSTAR: "item_superstar", BUBBLE: "item_bubble",
	SPRING: "item_spring", TICKLE: "item_tickle", TRIPLE_TURBO: "item_turbo3",
}
const ALL: Array[int] = [TURBO, SUPERSTAR, BUBBLE, SPRING, TICKLE, TRIPLE_TURBO]

## Odds (weights) by place, Mario Kart style: the leader gets small things, the middle a mix,
## the back of the field strong catch-up items. `behind` runs from 0 (leading) to 1 (last or
## far behind); the odds blend between the three tables.
const FRONT_ODDS := {BUBBLE: 40, TICKLE: 35, TURBO: 25}
const MIDDLE_ODDS := {TURBO: 40, SPRING: 20, TICKLE: 15, SUPERSTAR: 15, BUBBLE: 10}
const BACK_ODDS := {TRIPLE_TURBO: 40, SUPERSTAR: 30, TURBO: 20, SPRING: 10}
## A kid always gets something good, and the tickle for fun; behind, mostly turbos.
const KID_FRONT_ODDS := {TURBO: 30, SUPERSTAR: 20, SPRING: 30, TICKLE: 20}
const KID_BACK_ODDS := {TRIPLE_TURBO: 40, SUPERSTAR: 35, TURBO: 15, SPRING: 10}
## A grown-up driving ahead of a kid in the race gets the small things.
const AHEAD_OF_KID_ODDS := {BUBBLE: 45, TICKLE: 35, TURBO: 20}

## Short German words for the HUD hint next to the item slot (for the grown-ups; the pictures
## say the same).
const WORDS := {
	TURBO: "Turbo", SUPERSTAR: "Superstern", BUBBLE: "Schutzblase",
	SPRING: "Hüpfer", TICKLE: "Kitzeln", TRIPLE_TURBO: "3x Turbo",
}

static func word(item: int) -> String:
	return WORDS.get(item, "")

static func icon(item: int) -> String:
	return ICONS.get(item, "star")

## The odds for a racer. `behind` = 0 for the leader .. 1 for last place (or far behind).
static func odds_for(kid: bool, ahead_of_kid: bool, behind: float) -> Dictionary:
	var b := clampf(behind, 0.0, 1.0)
	if kid:
		return _blend(KID_FRONT_ODDS, KID_BACK_ODDS, b)
	if ahead_of_kid:
		return AHEAD_OF_KID_ODDS
	if b < 0.5:
		return _blend(FRONT_ODDS, MIDDLE_ODDS, b * 2.0)
	return _blend(MIDDLE_ODDS, BACK_ODDS, b * 2.0 - 1.0)

## Picks an item. `behind` = 0 for the leader .. 1 for last place.
static func pick(rng: RandomNumberGenerator, kid: bool, ahead_of_kid: bool, behind: float) -> int:
	var odds := odds_for(kid, ahead_of_kid, behind)
	var total := 0.0
	for item: int in odds:
		total += float(odds[item])
	var roll := rng.randf() * total
	for item: int in odds:
		roll -= float(odds[item])
		if roll <= 0.0:
			return item
	return TURBO

static func _blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for item: int in ALL:
		var w := lerpf(float(a.get(item, 0)), float(b.get(item, 0)), t)
		if w > 0.0:
			out[item] = w
	return out
