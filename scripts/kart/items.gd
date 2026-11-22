class_name Items extends RefCounted
## The friendly item set and who gets what. Nothing here hurts: the worst any item does is a
## short, funny wobble, and it never targets a kid-mode player.
##   TURBO      a boost
##   SUPERSTAR  a long boost; bumps and tickles cannot touch you meanwhile
##   BUBBLE     a shield that pops one tickle
##   SPRING     the kart jumps (with a trick and a landing boost)
##   TICKLE     a pink bubble flies to the kart ahead and makes it wobble (never to a kid)

enum { NONE, TURBO, SUPERSTAR, BUBBLE, SPRING, TICKLE }

const ICONS := {
	TURBO: "item_turbo", SUPERSTAR: "item_superstar", BUBBLE: "item_bubble",
	SPRING: "item_spring", TICKLE: "item_tickle",
}
const ALL: Array[int] = [TURBO, SUPERSTAR, BUBBLE, SPRING, TICKLE]

## Weights per item for a kid: always something good, and the tickle for fun.
const KID_ODDS := {TURBO: 30, SUPERSTAR: 25, SPRING: 25, TICKLE: 15, BUBBLE: 5}
## A grown-up driving ahead of a kid in the race gets the small things.
const AHEAD_OF_KID_ODDS := {BUBBLE: 45, TICKLE: 35, TURBO: 20}
## Everyone else by place: from the leader (0) to last (1), Mario Kart style.
const FRONT_ODDS := {BUBBLE: 40, TICKLE: 40, TURBO: 20}
const BACK_ODDS := {TURBO: 35, SUPERSTAR: 30, SPRING: 25, TICKLE: 10}

static func icon(item: int) -> String:
	return ICONS.get(item, "star")

## Picks an item. `behind` = 0 for the leader .. 1 for last place.
static func pick(rng: RandomNumberGenerator, kid: bool, ahead_of_kid: bool, behind: float) -> int:
	var odds: Dictionary
	if kid:
		odds = KID_ODDS
	elif ahead_of_kid:
		odds = AHEAD_OF_KID_ODDS
	else:
		odds = {}
		for item: int in ALL:
			odds[item] = lerpf(float(FRONT_ODDS.get(item, 0)), float(BACK_ODDS.get(item, 0)), clampf(behind, 0.0, 1.0))
	var total := 0.0
	for item: int in odds:
		total += float(odds[item])
	var roll := rng.randf() * total
	for item: int in odds:
		roll -= float(odds[item])
		if roll <= 0.0:
			return item
	return TURBO
