class_name Coalition
extends Resource

@export var target_id: String = ""				 # id religii-agresora, przeciwko któremu koalicja
@export var members: Array[String] = []			 # id religii uczestniczących
@export var turns_active: int = 0				 # liczba tur od powstania
@export var turns_without_conflict: int = 0		 # licznik do rozpadu (5 tur bez wojny → koniec)
