## Mechanika Pomostu Dyplomacja ↔ Wojna

**Data:** 2026-06-06
**Projekt:** church-manager
**Status:** Zatwierdzony
**Powiązane:** [system wasalstwa](07-vassalage-system-design.md), [system dyplomacji](03-diplomacy-system-design.md), [system wojen](02-war-system-design.md)

---

## Kontekst

Plan 07 spina trzy luźne sprzężenia między systemami dyplomacji (Plan 04-06) a systemem wojny (Plan 03):

1. **Wasale podążają za patronem w koalicji** — odłożone z Plan 06 sek.4 ("Auto-join klienta do koalicji/sojuszu patrona — Plan 07")
2. **Interdykt tworzy reaktywne CB** — odłożone z Plan 06 sek.7 ("Reaktywny CB Rewanż za zniewagę — wymaga integracji z WarManager.CB_AXIS_REQUIREMENTS")
3. **Sojusznicza święta wojna** — odłożone z Plan 06 sek.7 ("Transcendencja >65 → +15% siła sojuszu militarnego — brak konsumenta w obecnym kodzie")

Każdy komponent rozszerza istniejącą strukturę bez nowych klas danych. Wprowadza tylko 2 nowe pola na `Religion` (grievance tracking po Interdykcie) i poszerza istniejące metody w `DiplomacyManager` i `WarManager`.

---

## Sekcja 1: Model Danych

### Nowe pola na `Religion`

| Pole | Typ | Default | Cel |
|------|-----|---------|-----|
| `interdict_grievance_from_id` | `String` | `""` | id religii która ostatnio rzuciła na nas Interdykt; `""` = brak aktywnej zniewagi |
| `interdict_grievance_until` | `int` | `0` | tura do której (wyłącznie, używamy `>`) grievance pozwala użyć CB Rewanż |

Grievance to własność religii (target Interdyktu), nie pary. Powód: target może mieć zniewagę tylko od jednej religii naraz — kolejny Interdykt nadpisuje poprzednią. Jednorazowy charakter CB jest reprezentowany przez wyzerowanie obu pól po `declare_war(cb="rewanz")`.

Semantyka `>` (a nie `<=`) operatora porównania jest analogiczna do `interdict_immunity_until` w Plan 06 — okno wynosi *efektywnie* `GRIEVANCE_WINDOW_TURNS - 1 = 9` tur, ale stała nominalna to 10 dla spójności językowej i wykresów.

### Brak zmian w `RelationState`

Wasalskie auto-join koalicji nie wymaga nowych pól na RelationState — działa na podstawie istniejącego `Religion.suzerain_id` (Plan 06).

### Brak zmian w `War` / `Coalition`

Bonus Transcendencji w świętej wojnie i wasalskie auto-join nie wymagają nowych pól w War ani Coalition. Wszystko liczone ad-hoc z istniejących pól.

---

## Sekcja 2: Komponent A — Wasalskie auto-join koalicji

### Mechanika

Po fazie `auto_join_allies_to_coalitions` (Plan 04) w `_process_diplomacy`, dla każdej aktywnej koalicji wciągamy klientów członków koalicji. Klient (religia z `suzerain_id != ""`) automatycznie dołącza, gdy patron jest w `c.members` — niezależnie od tego czy patron został wciągnięty przez napięcie, sojusz czy wcześniejszy auto-join.

```
for c in state.active_coalitions:
    snapshot = c.members.duplicate()           # tylko obecni członkowie wciągają wasali
    for member_id in snapshot:
        if member_id == c.target_id: continue  # bezpiecznik (target nie powinien być członkiem, ale)
        for client in all_religions():
            if client.suzerain_id != member_id: continue
            if client.id == c.target_id: continue       # klient nie atakuje sam siebie
            if client.id in c.members: continue          # już członek
            c.members.append(client.id)
```

### Reguły

- **Snapshot pierwotnych członków** — analogicznie do `auto_join_allies_to_coalitions`. Klient klienta NIE jest wciągany w tej samej turze (1 poziom propagacji per turę). Jeśli klient patrona zostanie dodany w tej iteracji, jego *wasale* dołączą dopiero w następnej turze.
- **Patron jako target_id koalicji** — klient NIE dołącza (vetto relacji: klient nie atakuje swojego patrona). Ten przypadek występuje rzadko, ale jest możliwy: jeśli patron jest agresorem (declare_war), staje się target_id koalicji, a jego klient nie powinien być wciągany do koalicji *przeciw* patronowi.
- **Klient atakowany przez koalicję** — niezmieniony. Klient może być agresorem (target_id) niezależnie od patrona; auto-join nie wcia patrona do koalicji wymierzonej w klienta (asymetria — wybór "Klient → patron").
- **Brak prestige cost / duplikatów** — auto-join jest mechanicznym podążaniem, nie kosztuje prestiżu klienta. Idempotentne: kolejne wywołania w tej samej turze niczego nie dodają.

### Integracja w TurnManager

Wywołanie z `_process_diplomacy` po `auto_join_allies_to_coalitions`, przed `dissolve_coalitions`:

```
dm.evaluate_coalitions(state)
dm.auto_join_allies_to_coalitions(state)
dm.auto_join_vassals_to_coalitions(state)    # nowe w Plan 07
dm.dissolve_coalitions(state)
```

Kolejność: najpierw sojusznicy (przez alliance_active), potem wasale (przez suzerain_id). Wasale dodani w tej samej turze co ich patron — ale przez snapshot patrona jako jedyną oś (sojusznicy klienta NIE są wciągani w tej samej turze, nawet jeśli klient ma swoich sojuszników).

---

## Sekcja 3: Komponent B — CB Rewanż za zniewagę

### Mechanika

Reaktywny `casus_belli` aktywny tylko dla religii, która została ostatnio celem Interdyktu, jeśli spełnia warunek Ekskluzywizmu.

#### Krok 1: Zapis zniewagi w `proclaim_interdict`

Gdy Interdykt przechodzi wszystkie obecne guardy (włącznie z immunity z Plan 06), na końcu *przed* `return true`:

```
target.interdict_grievance_from_id = source_id
target.interdict_grievance_until = state.current_turn + GRIEVANCE_WINDOW_TURNS  # 10
```

#### Krok 2: Dostępność CB w `WarManager.available_casus_belli`

Sygnatura rozszerzona o `state`:

```gdscript
func available_casus_belli(attacker: Religion, defender: Religion, state: Node) -> Array[String]:
```

Po istniejącej iteracji `CB_AXIS_REQUIREMENTS` i sprawdzeniu `stlumienie_herezji`, dodajemy:

```
# Rewanż za zniewagę (Plan 07): reaktywne CB
if attacker.interdict_grievance_from_id == defender.id \
   and attacker.interdict_grievance_until > state.current_turn \
   and attacker.get_axis("C") < GRIEVANCE_EKSKLUZYWIZM_THRESHOLD:   # 30
    result.append("rewanz")
```

#### Krok 3: Zużycie zniewagi w `declare_war`

Po pomyślnej deklaracji wojny z `cb == "rewanz"` (przed `return war`):

```
if cb == "rewanz":
    attacker.interdict_grievance_from_id = ""
    attacker.interdict_grievance_until = 0
```

Jednorazowy CB — kolejna wojna Rewanż za tę samą zniewagę nie jest możliwa. Nowy Interdykt od tej samej religii resetuje grievance i daje świeże 10-turowe okno.

### Reguły

- **Warunek Ekskluzywizmu** — C < 30 (Ekskluzywizm >70). Religia tolerancyjna nie wypowiada wojny za teologiczną zniewagę.
- **Asymetria celów** — Rewanż musi być przeciw *konkretnemu* sprawcy Interdyktu. Próba `available_casus_belli(victim, other, state)` (gdzie `other != grievance_from_id`) nie zawiera "rewanz".
- **Okno czasowe** — `current_turn < grievance_until`. Jeśli `grievance_until = state.current_turn + 10` przy `T=20`, to działa dla `T ∈ [21..29]` (operator `>` jest ostry; w turze 30 grievance już wygasło). Spójne z immunity z Plan 06.
- **Nadpisywanie** — kolejny Interdykt od tej samej (lub innej) religii nadpisuje pole. Spec 03 nie wprowadza historii — tylko *ostatnia* zniewaga się liczy.
- **Self-Interdykt niemożliwy** — `proclaim_interdict` nie ma guard `source == target`, ale `get_or_create_relation` przy parze (X,X) tworzy zdegenerowaną relację z sortowaniem `[X,X]`. Plan 07 zakłada że self-Interdykt nie istnieje w przepływie gry (gracz/AI nie ma powodu). Jeśli zdarzy się w teście, `interdict_grievance_from_id` zostanie ustawione na własne id — co przy `available_casus_belli(self, self)` nigdy się nie wywoła (declare_war wymaga dwóch różnych religii).

### Stałe CB Rewanż

Dodanie do `WarManager.CB_BONUS`:

```
"rewanz": 0.15      # między wojna_sprawiedliwa (0.20) a stlumienie_herezji (0.15)
```

Brak wpisu w `CB_AXIS_REQUIREMENTS` — Rewanż jest reaktywny, dodawany dynamicznie w `available_casus_belli`. Statyczne axis-requirements (Ekskluzywizm >70) są sprawdzane bezpośrednio w kodzie reaktywnym.

---

## Sekcja 4: Komponent C — Bonus Transcendencji w świętej wojnie

### Mechanika

Religia atakująca w wojnie z CB `krucjata` lub `dzihad` dostaje +15% siły armii (multiplikatywnie do istniejącego axis_modifier), jeśli:
1. Atakujący ma `D > 65` (Transcendencja >65)
2. Atakujący ma aktywnego sojusznika (`RelationState.alliance_active == true`) który również prowadzi wojnę z CB `krucjata` lub `dzihad` (jako atakujący, dowolny defender)

Bonus jest *kontekstowy* — nie kumuluje się z innymi rolami sojusznika (np. ten sam sojusznik prowadzący ENDED wojnę nie liczy się, bo `war.state == "ENDED"` wykluczone).

### Implementacja w `compute_army_strength`

Po istniejącej pętli `AXIS_STRENGTH_MODIFIERS`, przed `cb_modifier`:

```
# Bonus świętej wojny sojuszniczej (Plan 07)
if war.casus_belli in HOLY_WAR_CBS \
   and religion.get_axis("D") > HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD \
   and _has_holy_war_ally(religion, state):
    axis_modifier += HOLY_WAR_ALLIANCE_BONUS
```

Gdzie helper:

```gdscript
func _has_holy_war_ally(religion: Religion, state: Node) -> bool:
    for rel: RelationState in state.relations:
        if not rel.alliance_active: continue
        var ally_id := ""
        if rel.religion_a_id == religion.id:
            ally_id = rel.religion_b_id
        elif rel.religion_b_id == religion.id:
            ally_id = rel.religion_a_id
        else:
            continue
        for war: War in state.active_wars:
            if war.state == "ENDED": continue
            if war.attacker_id == ally_id and war.casus_belli in HOLY_WAR_CBS:
                return true
    return false
```

### Reguły

- **Bonus kontekstowy, nie globalny** — bonus jest sprawdzany przy każdym wywołaniu `compute_army_strength`. W tej samej turze, jeśli sojusznik zakończy swoją krucjatę (force_loss, peace), bonus znika w następnym battle.
- **Wymóg sojuszu aktywnego** — `rel.alliance_active == true`. Sojusz nieaktywny lub zerwany nie daje bonusu.
- **Wymóg "atakujący w świętej wojnie"** — sojusznik musi być `war.attacker_id` w wojnie z CB krucjata/dzihad. Sojusznik *broniący* w krucjacie (jako defender_id) nie liczy się — bonus nagradza ofensywną koordynację.
- **Defender w krucjacie NIE dostaje bonusu** — jeśli `religion.id == war.defender_id`, bonus nie aplikowany, nawet jeśli ma D>65 i sojusznika prowadzącego krucjatę. Spec 03 sek.3 ramuje to jako "świętą wojnę" — bonus dla agresorów.
- **D > 65 ostro** — operator `>`, nie `>=`. Spójne z istniejącymi `AXIS_STRENGTH_MODIFIERS` (które używają `>=` w kodzie, ale nominalne progi w spec to "Transcendencja >65"). Plan 07: nowa stała `HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD = 65.0`, używana z operatorem `>`. To celowo *inaczej* niż istniejący `AXIS_STRENGTH_MODIFIERS["D"].min = 65` z `>=` — nie kumulujemy +25% i +15% na granicy D=65; nowy bonus aktywny dopiero przy D=66.
- **Kompatybilność z `defender_id`** — funkcja `compute_army_strength` jest wywoływana zarówno dla atakującego, jak i broniącego. Guard `religion.id == war.attacker_id` zapobiega aplikowaniu bonusu broniącemu.

### Stałe HolyWar

```
HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD = 65.0
HOLY_WAR_ALLIANCE_BONUS = 0.15
HOLY_WAR_CBS = ["krucjata", "dzihad"]
```

---

## Sekcja 5: Stałe (pełna lista Plan 07)

### `Religion` defaults

```
Religion.interdict_grievance_from_id = ""
Religion.interdict_grievance_until = 0
```

### `DiplomacyManager` — nowe stałe

```
# Grievance po Interdykcie
GRIEVANCE_WINDOW_TURNS = 10
GRIEVANCE_EKSKLUZYWIZM_THRESHOLD = 30.0   # C < 30 → Ekskluzywizm > 70
```

### `WarManager` — nowe stałe i wpisy

```
# Nowy CB
CB_BONUS["rewanz"] = 0.15

# Bonus świętej wojny sojuszniczej
HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD = 65.0
HOLY_WAR_ALLIANCE_BONUS = 0.15
HOLY_WAR_CBS = ["krucjata", "dzihad"]
```

### Zmiany sygnatur

```
WarManager.available_casus_belli(attacker, defender)
    → available_casus_belli(attacker, defender, state)
```

Wszystkie call-sites (testy + `declare_war`) zaktualizowane do nowej sygnatury.

---

## Sekcja 6: Sprzężenia i pętle

### Cykl Interdykt → Rewanż

1. Religia A (np. islam, prestiż 60, C=25 = Ekskluzywizm 75) rzuca Interdykt na B (np. judaizm)
2. B zapisuje grievance: `interdict_grievance_from_id = "islam", interdict_grievance_until = T+10`
3. Jeśli B ma C<30 (Ekskluzywizm >70), w turze T+1..T+9 może zadeklarować `declare_war(B, A, "rewanz")` z bonusem armii +15%
4. Po deklaracji grievance zerowane — kolejny Interdykt resetuje
5. Jeśli B ma C>=30 (tolerancyjny), grievance istnieje ale Rewanż niedostępny — B musi szukać innego CB lub czekać aż napięcie do koalicji

### Cykl wasalskie auto-join

1. Patron P (suzerain wielu klientów) zostaje wciągnięty do koalicji przeciw agresorowi G (przez napięcie ≥40)
2. W tej samej turze `auto_join_vassals_to_coalitions` dodaje wszystkich wasali P do koalicji
3. W następnej turze wasale tych wasali (jeśli istnieją) nie są jeszcze dodawani — 1 poziom propagacji per turę
4. Koalicja przeciw G ma teraz patrona + N klientów → masa krytyczna do skoordynowanego nacisku
5. Jeśli G zaprzestaje agresji (`compute_threat_index < 30`), koalicja rozpada się normalnie przez `dissolve_coalitions` — wasale wycofują się razem z patronem

### Cykl święta wojna sojusznicza

1. Religie X i Y (obie z D>65, alliance_active) deklarują równolegle krucjaty (X→A, Y→B; różne defenderzy)
2. W każdej battle obu wojen `compute_army_strength` zwraca +15% dla atakującego — bonus nawet bez wspólnego defendera
3. Jeśli jedna ze stron sojuszu kończy krucjatę (peace lub force_loss), druga traci +15% w swojej krucjacie
4. Asymetria z `_has_holy_war_ally`: sojusznik *broniący* w krucjacie NIE liczy się. Tylko ofensywne sprzężenia.

---

## Sekcja 7: Co NIE wchodzi do Plan 07

- **`[Dołącz do potępienia]`** po Interdykcie — wymaga NPC decision system, AI gracze automatycznie wystawiający Interdykt po pierwszym → przyszłość
- **Wielokrotne grievance / historia zniewag** — Plan 07 trzyma tylko *ostatnią* zniewagę. Kolejny Interdykt nadpisuje. Historię można dodać przyszłym `Religion.grievance_log: Array`.
- **Rewanż jako CB dla sojusznika victima** — tylko bezpośrednia ofiara Interdyktu może użyć Rewanżu. Sojusznik nie dziedziczy zniewagi.
- **Bonus Transcendencji dla broniącego w krucjacie** — Plan 07 implementuje wyłącznie ofensywny bonus. Defender w krucjacie nie dostaje +15% nawet jeśli ma D>65 i sojusznika w świętej wojnie.
- **Multi-party wars / koalicja jako jeden warfront** — `War` pozostaje 1v1. Koalicja to lista nazw, ale każda wojna jest osobna; bonus świętej wojny sumuje się ad-hoc z różnych wojen sojuszników.
- **Kumulacja kilku sojuszników D>65** — Plan 07 daje stały +15% jeśli *jakikolwiek* sojusznik prowadzi krucjatę. Posiadanie dwóch sojuszników w krucjatach nie daje +30%.
- **Auto-join klienta do sojuszu obronnego patrona** (poza koalicjami) — Plan 07 dotyka tylko koalicji. Sojusze (alliance_active) pozostają parami religia↔religia, klient nie dziedziczy sojuszy patrona.
- **Rewanż dla Ekskluzywizm <=70** — sztywny próg C<30. Religia tolerancyjna nie dostaje narzędzia zemsty.
- **+5 prestiżu/turę za >10 tur pokoju** — wymaga osobnego trackingu `last_conflict_turn`, odłożone.
- **UI Plan 07** — przyciski "[Rewanż za zniewagę]", "Sojusznicy w krucjacie" → dedykowany plan UI.

---

## Otwarte pytania (poza zakresem Plan 07)

- Czy bonus świętej wojny powinien skalować z liczbą sojuszników w krucjacie (1→+15%, 2→+25%, 3→+30%)? Plan 07: stały +15% (YAGNI; multi-ally rzadkie w fazie PoC).
- Czy Rewanż powinien mieć modyfikator zaufania (np. trust < 30 → CB dostępny bez ograniczenia C<30)? Plan 07: nie, tylko warunek osi.
- Czy wasalskie auto-join powinno respektować `theological_trust`? Np. klient z trust<20 z patronem nie podąża? Plan 07: nie — wasalstwo jest deterministyczne, niezależne od trust.
- Czy bonus Transcendencji powinien rozszerzać się na CB `wojna_sprawiedliwa` przy D>50? Plan 07: tylko krucjata/dżihad (spec 03 sek.3).
