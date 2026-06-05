class_name War
extends Resource

@export var attacker_id: String = ""
@export var defender_id: String = ""
@export var casus_belli: String = ""        # krucjata | dzihad | wojna_sprawiedliwa | nawrocenie_mieczem | stlumienie_herezji
@export var state: String = "MOBILIZING"    # MOBILIZING | BATTLING | OCCUPYING | ENDED
@export var turns_in_state: int = 0
@export var contested_provinces: Array[String] = []
@export var battles_won: int = 0
@export var battles_lost: int = 0
@export var outcome: String = ""            # "" | WIN | LOSS | DRAW (po ENDED)
