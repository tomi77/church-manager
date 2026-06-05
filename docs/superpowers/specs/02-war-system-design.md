# Mechanika Systemu Wojen

**Data:** 2026-06-04
**Projekt:** church-manager
**Status:** Zatwierdzony
**Powiązane:** [system doktryn](2026-06-03-doctrine-system-design.md)

---

## Kontekst

Wojna pełni dwie role jednocześnie: jest narzędziem ekspansji doktrynalnej (zdobywasz terytoria i wyznawców do asymilacji) oraz konsekwencją konfliktu doktrynalnego (schizmy, herezje i ekskomuniki prowadzą do zbrojnego starcia). Bitwy rozstrzygane są abstrakcyjnie — bez map bitewnych. Centrum gry pozostaje doktryna, nie taktyka.

---

## Sekcja 1: Wyzwalacze i Casus Belli

Każda wojna wymaga tytułu prawnego (CB). Cztery źródła CB — od oportunistycznych po wymuszone.

### CB z doktryny — akcje progowe

Konkretne kombinacje pozycji na osiach odblokowują tytuły do wojny:

| CB | Warunek doktrynalny | Bonus | Ograniczenie |
|----|---------------------|-------|--------------|
| `[Krucjata]` | Ekskluzywizm >75, Doczesność >60 | +30% siła, +morale | cel musi być "nieprawy" |
| `[Dżihad]` | Ekskluzywizm >75, Transcendencja >70 | +40% siła, +prestiż | jeden aktywny na raz |
| `[Wojna Sprawiedliwa]` | Hierarchia >60, Doczesność >50 | +20% siła | tylko w obronie lub rewanżu |
| `[Nawrócenie Mieczem]` | Ekskluzywizm >60, Dogmatyzm >65 | po zwycięstwie: przymus nawracania | blokuje asymilację |

### Schizma / herezja jako CB

Gdy frakcja schizmatycka osiąga Fazę 3 i tworzy nową religię, automatycznie pojawia się CB `[Stłumienie Herezji]`. Można go użyć również przeciw zewnętrznej religii, jeśli ta wspiera heretycki ruch wewnątrz twojego kościoła.

### Obowiązkowe wojny

Przy Ekskluzywizmie >80 niektóre zdarzenia losowe generują `[Fatwa]` lub `[Sobór Wojenny]` — decyzja jest obowiązkowa. Odmowa = -prestiż, +napięcie frakcji wojowniczej. Gracz nie zawsze chce wojny, ale doktryna go do niej popycha.

---

## Sekcja 2: Rozstrzyganie bitew

### Formuła siły militarnej

```
Siła atakującego = Baza militarna × Modyfikator doktryny × Modyfikator terenu × Modyfikator CB
```

Baza militarna zależy od liczby wiernych, poziomu zorganizowania kleru i zasobów. Gracz nie zarządza jednostkami — zarządza warunkami, które tę bazę budują.

### Modyfikatory doktrynalne

| Oś | Efekt militarny |
|----|-----------------|
| Dogmatyzm >60 | +15% siła przy aktywnym CB teologicznym |
| Hierarchia >60 | +20% szybkość mobilizacji |
| Transcendencja >65 | +25% morale (trudniej złamać armię) |
| Doczesność >65 | +15% do siły ekonomicznej (dłuższe kampanie) |
| Synkretyzm >60 | +10% przy wojnach z religiami, z którymi masz kontakt |
| Ekskluzywizm >75 | odblokowuje CB wojenne |

### Wynik i probabilistyka

Wynik nie jest deterministyczny — to rzut ważony:

```
Atak na Anatolię:
  Twoja siła:          847
  Wroga siła:          612
  Modyfikator terenu:  -10%  (góry)
  Modyfikator CB:      +25%  (Dżihad)
  → Zwycięstwo z 82% prawdopodobieństwem
```

Przegrana przy przewadze jest możliwa i generuje zdarzenia fabularne (klęska jako kara boska, kryzys doktrynalny).

### Przebieg kampanii

Zamiast jednej bitwy, kampania składa się z 2–4 etapów:

1. **Mobilizacja** — gracz wydaje zasoby, CB aktywuje modyfikatory
2. **Starcie** — wynik probabilistyczny, możliwa interwencja przez decyzję kluczową (np. `[Ogłoś świętą wojnę]` w trakcie kampanii za koszt prestiżu)
3. **Oblężenie lub negocjacje** — jeśli wygrałeś starcie, decydujesz jak zakończyć wojnę
4. **Pokój** — warunki pokoju i konsekwencje doktrynalne

---

## Sekcja 3: Konsekwencje i łupy doktrynalne

### Warunki pokoju

Po wygraniu kampanii gracz negocjuje lub narzuca warunki:

| Warunek | Efekt natychmiastowy | Efekt długofalowy |
|---------|---------------------|-------------------|
| `[Aneksja terytorialna]` | zdobywasz prowincję z jej ludnością | presja synkretyczna jeśli zasymilowana |
| `[Trybut]` | stały dochód zasobów od pokonanej religii | pokonana religia akumuluje urazę |
| `[Wymuszony sobór]` | pokonana religia przesuwa się na osi w twoim kierunku | jej frakcje tracą stabilność |
| `[Eksterminacja kleru]` | eliminujesz wrogą frakcję kapłańską | trwała destabilizacja pokonanej religii |
| `[Unia pod twoim zwierzchnictwem]` | pokonana religia staje się kościołem zależnym | możliwa przyszła schizma jeśli źle zarządzana |

### Polityka wobec podbitej ludności

Przy aneksji terytorialnej gracz wybiera:

| Opcja | Zysk | Koszt |
|-------|------|-------|
| `[Wypędź]` | czyste terytorium, zero presji | utrata potencjalnych wiernych |
| `[Nawracaj]` | powolny przyrost wiernych, czysta doktryna | czas i zasoby, opór lokalny |
| `[Zasymiluj]` | natychmiastowy element doktrynalny obcej religii | presja synkretyczna, napięcie frakcji konserwatywnej |

### Klęska i jej konsekwencje

Przegrana wojna generuje kryzys doktrynalny:

- Frakcja wojownicza traci wpływ (skoro "Bóg nie pobłogosławił")
- Zdarzenie `[Teologia klęski]` — gracz musi teologicznie wyjaśnić porażkę, co przesuwa jedną oś
- Utrata terytoriów z wierzącymi → automatyczna presja na frakcje, możliwa schizma z rozpaczy

**Przykład:** islamska armia przegrywa z chrześcijanami → event `[Dlaczego Allah dopuścił klęskę?]` → opcje: `[Kara za grzechy]` (Dogmatyzm +5), `[Wola niezbadana]` (Mistycyzm +8), `[Reformujemy się]` (Równouprawnienie +6).

---

## Sekcja 4: Koszty i ograniczenia

### 1. Zmęczenie wojenne (0–100)

| Próg | Konsekwencja |
|------|-------------|
| >30 | -10% siła militarna, frakcja pokojowa zaczyna naciskać |
| >55 | -20% zadowolenie wiernych, odpływ w prowincjach przyfrontowych |
| >75 | frakcja pokojowa wchodzi w Fazę 1 (ruch heretycki) |
| >90 | gracz zmuszony do zawieszenia broni lub schizma frakcji pokojowej |

Zmęczenie spada powoli w czasie pokoju lub szybko przez `[Sobór Pokojowy]` (koszt: prestiż).

### 2. Presja międzynarodowa

| Wskaźnik zagrożenia | Konsekwencja |
|--------------------|-------------|
| >50 | inne religie mogą tworzyć koalicje obronne |
| >75 | automatyczny CB `[Obrona przed agresorem]` dla wszystkich sąsiadów |

Wskaźnik spada przez dyplomację, sojusze ekumeniczne lub długi pokój.

### 3. Koszt doktrynalny asymilacji

Każda zasymilowana prowincja przesuwa oś C w kierunku Synkretyzmu — nawet jeśli gracz tego nie chce. Ekspansja przez wojnę nieuchronnie zmienia tożsamość religii. Alternatywa `[Nawracaj]` jest bezpieczna doktrynalnie, ale wolna i kosztowna.

### 4. Frakcje pacyfistyczne

Przy Transcendencji >60 i Równouprawnieniu >70 frakcja pacyfistyczna nabiera wpływów:

- Poniżej progu: głosuje przeciw CB na soborach, -20% do mobilizacji
- Przy Równouprawnieniu >85: gracz nie może wypowiedzieć wojny ofensywnej bez zgody soboru (który może odmówić)

Religie pokojowe mają realną przewagę — więcej zasobów, szybszy wzrost wiernych — ale są podatne na agresję zewnętrzną.

---

## Sekcja 5: Krucjata i Dżihad — meta-mechanika

Najdramatyczniejsza akcja w grze. Dostępna raz na epokę, zmienia układ sił globalnie.

### Warunki ogłoszenia

| Warunek | Wartość |
|---------|---------|
| Ekskluzywizm | >75 |
| Transcendencja | >65 |
| Prestiż religii | >500 |
| Zmęczenie wojenne | <20 |
| Cooldown od poprzedniej | min. 1 epoka (≈50 tur) |

### Mechanika zjednoczenia

Po ogłoszeniu:

1. Wszystkie schizmatyckie odłamy twojej religii (NPC) dostają propozycję `[Dołącz do świętej wojny]` — większość akceptuje, zawieszając wzajemne konflikty
2. Twoja siła militarna rośnie o sumę sił wszystkich uczestniczących odłamów
3. Frakcje wewnętrzne tymczasowo zawieszają napięcia

**Ryzyko:** odłamy mają swoje warunki uczestnictwa. Jeśli po wojnie ich nie spełnisz (podział łupów, zmiany doktrynalne), napięcie po Krucjacie jest większe niż przed nią.

### Wynik

| Wynik | Konsekwencja |
|-------|-------------|
| Pełne zwycięstwo | cel traci 50–80% terytorium, płaci trybut przez 3 epoki |
| Pyrrusowe zwycięstwo | zwycięstwo militarne, ale zmęczenie >80 → natychmiastowy kryzys frakcji |
| Porażka | `[Klęska Świętej Wojny]` — teologia klęski na maksimum, schizma prawie nieuchronna |

### Konsekwencje doktrynalne

| Wynik | Zmiana osi |
|-------|-----------|
| Zwycięstwo | Ekskluzywizm +10, Synkretyzm -10, Transcendencja ±8 |
| Porażka | Ekskluzywizm -15, napięcie frakcji wojowniczej na max |

Wygrany Dżihad zbliża religię do ekstremalnego Ekskluzywizmu — co może wywołać kolejne obowiązkowe wojny. Zwycięstwo karmi samo siebie.

---

## Sekcja 6: Spójność z systemem doktryn

### Pętle sprzężeń zwrotnych

| Sytuacja | Konsekwencja | Efekt na doktrynę |
|----------|-------------|-------------------|
| Wygrana Krucjata + asymilacja | Synkretyzm rośnie mimo Ekskluzywizmu | napięcie frakcji konserwatywnej |
| Klęska wojenna | `[Teologia klęski]` wymusza ruch na osi | niespodziewana zmiana tożsamości religii |
| Obowiązkowa fatwa przy pacyfistycznej frakcji | frakcja blokuje mobilizację | gracz uwięziony między doktryną a frakcją |
| Schizma po Krucjacie | nowa religia z podobnym Ekskluzywizmem | konkurent do tych samych CB wojennych |

### Przykładowy łańcuch zdarzeń

1. Religia osiąga Ekskluzywizm 78 i Transcendencję 68 → odblokowany `[Dżihad]`
2. Gracz ogłasza Dżihad przeciw chrześcijanom → odłamy przyłączają się
3. Zwycięstwo, aneksja Anatolii → `[Zasymiluj]` → Synkretyzm: 28→41
4. Frakcja konserwatywna: napięcie 30→55 → Faza 1: ruch heretycki
5. Zmęczenie wojenne 72 → frakcja pokojowa naciska → sobór pokojowy lub kolejna kampania
6. Gracz decyduje na sobór → Ekskluzywizm spada do 68 → `[Dżihad]` zablokowany
7. Frakcja wojownicza niezadowolona → nowe napięcie

Gracz wygrał wojnę i stracił kontrolę nad własną religią.

### Propozycja wartości

Wojna nie jest narzędziem ekspansji — jest **testem doktrynalnym**. Każdy konflikt zmienia religię: przez asymilację, przez klęskę, przez zmęczenie, przez sojusze. Religia, która dużo walczy, nieuchronnie staje się czymś innym niż zaczęła.

---

## Otwarte pytania do dalszego projektowania

- Jak wygląda mapa i system prowincji? (sąsiedztwo decyduje o presji i dostępie do CB)
- Czy neutralne terytoria (bez religii) istnieją jako cel ekspansji?
- Jak działa dyplomacja między religiami poza kontekstem wojennym?
- Czy gracz może prowadzić wojnę domową (np. stłumienie schizmy siłą wewnątrz własnych prowincji)?

---

## Apendyks A: Decyzje implementacyjne (Plan 3a, 2026-06-05)

Brainstorming Plan 3 podzielił spec wojny na trzy plany implementacyjne. Apendyks dokumentuje, co wchodzi w fundament (3a), a co odsuwamy na później.

### Podział spec → plany

| Sekcja speca | Plan 3a (fundament) | Plan 3b (Dyplomacja) | Plan 3c (Meta-mechaniki) |
|---|---|---|---|
| Sekcja 1: CB z doktryny (4 typy) | ✓ | – | – |
| Sekcja 1: CB ze schizmy `[Stłumienie Herezji]` | ✓ (akcja gracza) | – | – |
| Sekcja 1: Obowiązkowe wojny `[Fatwa]`/`[Sobór Wojenny]` | – | – | ✓ |
| Sekcja 2: Formuła siły + modyfikatory | ✓ | – | – |
| Sekcja 2: Etapy kampanii (4 stany) | ✓ | – | – |
| Sekcja 3: Aneksja + polityka asymilacji | ✓ | – | – |
| Sekcja 3: Wymuszony sobór | ✓ | – | – |
| Sekcja 3: Eksterminacja kleru | ✓ | – | – |
| Sekcja 3: Trybut | – | ✓ (wymaga Religion.resources) | – |
| Sekcja 3: Unia pod zwierzchnictwem | – | ✓ (wymaga vassalage) | – |
| Sekcja 3: Klęska + Teologia klęski | ✓ (pending event) | – | – |
| Sekcja 4: Zmęczenie wojenne | ✓ | – | – |
| Sekcja 4: Wskaźnik zagrożenia | – | ✓ | – |
| Sekcja 4: Frakcje pacyfistyczne jako blokada | – | – | ✓ |
| Sekcja 5: Krucjata/Dżihad jako meta-mechanika | – | – | ✓ |

### Kluczowe decyzje projektowe

1. **CB ze schizmy = akcja gracza.** `SchismManager.trigger_schism` nie tworzy automatycznie CB. Gracz musi sam wypowiedzieć wojnę religii-córce.
2. **Baza militarna = populacja prowincji + prestiż.** "Kler" ze speca pomijamy (brak modelu w grze).
3. **RNG = `randf()` Godota.** Testy na skrajnych proporcjach sił (np. 10000 vs 10 → niemal pewne zwycięstwo), nie deterministyczne.
4. **4-stanowa kampania.** `MOBILIZING` (2 tury) → `BATTLING` (atak per prowincja) → `OCCUPYING` (2 tury po wygranej, broniący może kontratak) → `ENDED`.
5. **Cele wojny = brak listy.** `declare_war(attacker, defender, cb)` bez prowincji. Atakujący wybiera prowincje opportunistycznie w `attack_province`. Okupowane prowincje akumulują się w `War.contested_provinces`. Przy pokoju gracz wybiera, które aneksować.
6. **Zmęczenie = per religia globalnie.** Pole `Religion.war_weariness: float = 0.0`. Suma efektów ze wszystkich aktywnych wojen religii.
7. **Religia-córka schizmatyczna** identyfikowana przez nowe pole `Religion.parent_religion_id: String = ""`. `SchismManager.trigger_schism` wypełnia je przy tworzeniu nowej religii.
8. **Bez limitu równoczesnych wojen.** Religia może mieć wiele aktywnych. Limity (np. "jeden Dżihad") odłożone do Plan 3c.
9. **Klęska = pending event.** `DefeatEvent` w `GameState.pending_defeat_events`, analogicznie do `pending_ideas`. Gracz wybiera 1 z 3 predefiniowanych opcji teologicznych (każda przesuwa inną oś).
10. **Asymilacja prestiżowo neutralna.** `[Wypędź]` / `[Nawracaj]` / `[Zasymiluj]` różnią się tylko efektami populacji i osi C — żadna z opcji nie daje ani nie zabiera prestiżu.

### Formuła siły militarnej (PoC)

```
strength = (sum(pop_owned) × 0.1 + prestige × 2.0)
        × (1 + axis_modifiers)        # 6 progów osi, sumowane
        × (1 + cb_bonus)               # 0.10 (nawrocenie_mieczem) do 0.40 (dzihad)
        × (1 - weariness_penalty)      # 0 / 0.10 / 0.20 / 0.30
        × (1 + terrain_modifier)       # tylko broniący prowincji

p_win = atk_strength / (atk_strength + def_strength)
victory = randf() < p_win
```

**Modyfikatory osi (sumowane do `axis_modifiers`):**

| Próg | Modyfikator |
|---|---|
| Dogmatyzm (A) >60 | +0.15 |
| Hierarchia (B) >60 | +0.20 |
| Transcendencja (D) >65 | +0.25 |
| Doczesność (D) >65 | +0.15 |
| Synkretyzm (C) >60 | +0.10 |

**Modyfikator terenu (broniący w prowincji):**

| Teren | Modyfikator |
|---|---|
| mountains | +0.15 |
| desert | +0.10 |
| fertile | +0.05 |
| plains, coast | 0 |

**Kara za zmęczenie:**

| war_weariness | Penalty |
|---|---|
| >30 | -0.10 |
| >55 | -0.20 |
| >75 | -0.30 |

### Model danych

**Nowe pliki:**

```gdscript
# scripts/engine/War.gd
class_name War
extends Resource

@export var attacker_id: String = ""
@export var defender_id: String = ""
@export var casus_belli: String = ""        # krucjata|dzihad|wojna_sprawiedliwa|nawrocenie_mieczem|stlumienie_herezji
@export var state: String = "MOBILIZING"    # MOBILIZING|BATTLING|OCCUPYING|ENDED
@export var turns_in_state: int = 0
@export var contested_provinces: Array[String] = []
@export var battles_won: int = 0
@export var battles_lost: int = 0
@export var outcome: String = ""            # ""|WIN|LOSS|DRAW (po ENDED)
```

```gdscript
# scripts/engine/DefeatEvent.gd
class_name DefeatEvent
extends Resource

@export var religion_id: String = ""
@export var opponent_id: String = ""
@export var cb: String = ""
@export var options: Array = []   # Array[Dictionary]: {label, axis, delta}
```

**Modyfikacje istniejących plików:**

```gdscript
# Religion.gd — dodaj:
@export var war_weariness: float = 0.0
@export var parent_religion_id: String = ""

# GameState.gd — dodaj:
var active_wars: Array[War] = []
var pending_defeat_events: Array[DefeatEvent] = []

# SchismManager.gd — w trigger_schism:
new_rel.parent_religion_id = religion.id
```

### API `WarManager` (stateless RefCounted)

```gdscript
class_name WarManager
extends RefCounted

# Stałe (wybór)
const MOBILIZATION_TURNS := 2
const OCCUPATION_TURNS := 2
const WEARINESS_PER_TURN := 3.0
const WEARINESS_FORCED_PEACE := 90.0
const DECLARE_WAR_PRESTIGE := 10
const BASE_POPULATION_FACTOR := 0.1
const BASE_PRESTIGE_FACTOR := 2.0

# Publiczne API
func available_casus_belli(attacker: Religion, defender: Religion) -> Array[String]
func declare_war(attacker_id: String, defender_id: String, cb: String, state: Node) -> War
func compute_army_strength(religion: Religion, target_province: Province, war: War, state: Node) -> float
func attack_province(war: War, province_id: String, state: Node) -> Dictionary  # {victory, atk_str, def_str, p_win}
func offer_peace(war: War, terms: Dictionary, state: Node) -> bool
func resolve_defeat(event: DefeatEvent, option_index: int, state: Node) -> void

# Warunki pokoju (wywoływane wewnętrznie przez offer_peace)
func _apply_annexation(war, province_ids: Array[String], policy: String, state: Node) -> void
func _apply_forced_council(war, axis: String, delta: float, state: Node) -> void
func _apply_clergy_extermination(war, faction_id: String, state: Node) -> void
```

### Integracja z `TurnManager`

W `process_turn` po istniejących krokach (presja → relikwie → napięcie frakcji → uczeni → exodus) dodajemy `_process_active_wars(state)`:

- inkrementacja `turns_in_state` dla każdej `War`
- `MOBILIZING` → `BATTLING` po `MOBILIZATION_TURNS`
- `OCCUPYING` → `BATTLING` po `OCCUPATION_TURNS`
- nalicza `war_weariness` (`+= WEARINESS_PER_TURN`) dla obu stron każdej aktywnej wojny
- gdy `war_weariness >= WEARINESS_FORCED_PEACE` → `War.state = "ENDED"`, `outcome = "LOSS"` dla strony nad progiem, tworzy `DefeatEvent` w `pending_defeat_events`
