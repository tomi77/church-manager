class_name GameOutcome
extends Resource

# Resource opisujący końcowy stan gry. GameState.game_outcome != null oznacza
# że gra jest zakończona (VictoryManager.check ustawia, MainShell pokazuje modal).

@export var winner_id: String = ""	# id religii która wygrała (zawsze niepusty — także przy fallback turn_limit)
@export var reason: String = ""		# patrz GameOverDialog reason mapping w Task 15
@export var end_turn: int = 0		# numer tury w momencie ustawienia outcome
@export var ranking: Array = []		# Array[Dictionary{religion_id: String, prestige: int, provinces: int}], DESC po prestiżu
