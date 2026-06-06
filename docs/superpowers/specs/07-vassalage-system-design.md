# Mechanika Systemu Wasalstwa

**Data:** 2026-06-06
**Projekt:** church-manager
**Status:** Zatwierdzony
**Powiązane:** [system dyplomacji](03-diplomacy-system-design.md), [system doktryn](01-doctrine-system-design.md)

---

## Kontekst

Wasalstwo konkretyzuje akcję `[Uznanie Zwierzchnictwa]` ze spec 03 (sekcja 2) oraz dwa specjalne sobory wynikające z modyfikatorów osi (spec 03, sekcja 3): `[Sobór Wasalny]` (Hierarchia >75) i `[Sobór Ludowy]` (Równouprawnienie >70).

Model to relacja asymetryczna: jedna religia (klient) podporządkowuje się drugiej (patron) w zamian za ochronę i dochód. Patron zyskuje prawo do wymuszania zmian doktrynalnych u klienta przez Sobór Wasalny. Klient narasta napięcie wewnętrzne (frakcja konserwatywna) i może się zbuntować. Sobór Ludowy to odrębny element — narzędzie obronne demokratycznych religii (B<30) przeciw Interdyktowi Dyplomatycznemu.

Wasalstwo wprowadza pierwszy w silniku zasób inny niż prestiż — `Religion.resources` (ogólny strumień ekonomiczny). Trybut to przepływ tego zasobu klient → patron.

---

## Sekcja 1: Model Danych

### Nowe pola na `Religion`

| Pole | Typ | Default | Cel |
|------|-----|---------|-----|
| `resources` | `int` | `0` | ogólny zasób ekonomiczny; floor 0 |
| `suzerain_id` | `String` | `""` | id patrona; `""` = niepodległa religia |
| `interdict_immunity_until` | `int` | `0` | tura do której (włącznie) Interdykt jest zablokowany |

Klient ma maksymalnie jednego patrona — to własność religii, nie pary. Patron może mieć wielu klientów (relacja 1:N), wyliczanych ad-hoc z `state.all_religions()`.

### Nowe pola na `RelationState`

| Pole | Typ | Default | Cel |
|------|-----|---------|-----|
| `vassal_council_cooldown_until` | `int` | `0` | tura do której (włącznie) Sobór Wasalny dla tej pary jest na cooldown |

Cooldown żyje na relacji, bo ogranicza jedną parę patron↔klient (a nie globalnie patrona).

### Brak nowych klas

Wasalstwo nie wymaga osobnego `Vassalage` Resource — wszystkie informacje są wyrażalne polami istniejących klas. Spójne z `RelationState.alliance_active` (jedno boolean pole zamiast osobnej klasy `Alliance`).

---

## Sekcja 2: Akcje Dyplomatyczne

### `[Uznanie Zwierzchnictwa]` (`recognize_suzerainty`)

Inicjuje klient. Po zaakceptowaniu klient ustawia `suzerain_id`, patron jednorazowo zyskuje prestiż i wzajemna współpraca ekonomiczna rośnie.

| Element | Wartość |
|---------|---------|
| Inicjator | klient |
| Wymagania klienta | `A < SUZERAINTY_DOGMATYZM_BLOCK` (Dogmatyzm ≤80, spec 03 sek.3), brak istniejącego patrona |
| Wymagania pary | `theological_trust > SUZERAINTY_TRUST_THRESHOLD`, brak aktywnej wojny między stronami |
| Efekt na klienta | `suzerain_id = patron_id` |
| Efekt na patrona | `prestige += SUZERAINTY_PATRON_PRESTIGE_GAIN` |
| Efekt na relację | `economic_cooperation += SUZERAINTY_ECON_GAIN` (clamp 0..100) |

Blokady same w sobie wynikają ze spec 03:
- `A ≥ 80` (Dogmatyzm >80) — "doktryna zabrania podporządkowania obcemu autorytetowi"
- Niska zaufanie — klient nie podda się obcemu, którego nie poważa
- Aktywna wojna — quasi-wrogowie nie zawierają unii personalnej

### `[Sobór Wasalny]` (`vassal_council`)

Inicjuje patron. Wymusza shift osi u klienta bez jego zgody. Generuje napięcie u dominującej frakcji klienta — narzędzie powolnego ucisku, które prowadzi do buntu (sekcja 3).

| Element | Wartość |
|---------|---------|
| Inicjator | patron |
| Wymagania patrona | `B > VASSAL_COUNCIL_HIERARCHIA_THRESHOLD` (75), `prestige ≥ VASSAL_COUNCIL_PRESTIGE_COST` |
| Wymagania pary | `client.suzerain_id == patron_id`, `current_turn > rel.vassal_council_cooldown_until` |
| Parametry | `axis ∈ {A, B, C, D}`, `delta ∈ ±[VASSAL_COUNCIL_MIN_AXIS_DELTA, VASSAL_COUNCIL_MAX_AXIS_DELTA]` (3..8) |
| Efekt na klienta | `shift_axis(axis, delta)`; `dominant_faction.tension += VASSAL_COUNCIL_CLIENT_TENSION_BUMP` (15) |
| Efekt na patrona | `prestige -= VASSAL_COUNCIL_PRESTIGE_COST` (30) |
| Efekt na relację | `vassal_council_cooldown_until = current_turn + VASSAL_COUNCIL_COOLDOWN_TURNS` (5) |

Delta przekazana spoza zakresu jest klampowana z zachowaniem znaku (`signf * clampf(absf(delta), MIN, MAX)`) — analogicznie do `ecumenical_council`.

Asymetria względem Soboru Ekumenicznego (Plan 05):
- Sobór Ekumeniczny: patron shiftuje *własną* oś, obie strony zyskują (trust +15, tension -10)
- Sobór Wasalny: patron shiftuje *cudzą* oś, tylko klient cierpi (tension frakcji)

### `[Sobór Ludowy]` (`people_council`)

Inicjuje religia o niskiej Hierarchii (B<30, Równouprawnienie >70). Daje sobie czasową immunizację przeciw Interdyktowi Dyplomatycznemu (sekcja 4).

| Element | Wartość |
|---------|---------|
| Inicjator | sama religia |
| Wymagania | `B < PEOPLE_COUNCIL_ROWNOUPRAWNIENIE_THRESHOLD` (30), `prestige ≥ PEOPLE_COUNCIL_PRESTIGE_COST` |
| Efekt | `interdict_immunity_until = current_turn + PEOPLE_COUNCIL_IMMUNITY_TURNS` (5) |
| Koszt | `prestige -= 15` |

Nie ma celu (target_id) — to akcja na sobie. Strategiczna decyzja: czy wystawić *teraz* (preemptywnie), czy poczekać aż zagrożenie się skonkretyzuje (ryzyko że Interdykt przyjdzie wcześniej).

### Modyfikacja `[Interdykt Dyplomatyczny]`

`proclaim_interdict` dostaje dodatkowy guard:

```
if target.interdict_immunity_until > state.current_turn:
    return false
```

Inne blokady i koszty bez zmian.

---

## Sekcja 3: Mechaniki Per-Turn

### Przepływ zasobów (`_process_resources`)

Wywoływane w `process_turn` po `_process_diplomacy`.

```
for r in all_religions():
    r.resources += PASSIVE_INCOME_PER_TURN          # +5 wszystkim
for client in all_religions():
    if client.suzerain_id == "": continue
    patron = state.get_religion(client.suzerain_id)
    if patron == null: continue
    amount = min(TRIBUTE_PER_TURN, client.resources)  # floor 0
    client.resources -= amount
    patron.resources += amount
```

Kolejność: najpierw passive income wszystkim, potem trybut. To gwarantuje, że klient zaczyna turę z dochodem `PASSIVE_INCOME - TRIBUTE = 5 - 3 = 2` per turę netto. Wasalstwo jest opłacalne — klient nie wpada w nędzę szybko, a patron dostaje stały bonus.

Floor 0: jeśli klient ma 0 resources (przez zewnętrzne zubożenie, np. przyszłe mechaniki grabieży), patron dostaje mniej. Realistycznie: zbankrutowany wasal nie płaci.

Trybut jest jednokierunkowy. Patron nie zwraca niczego klientowi — "ochrona przez sojusz obronny patrona" ze spec 03 to mechanika narracyjna (klient w przyszłości automatycznie dołącza do sojuszy patrona w koalicjach — out of scope dla Plan 06, odłożone do Plan 07).

### Auto-bunt (`_process_vassal_revolts`)

Wywoływane w `process_turn` po `_process_resources`.

```
for client in all_religions():
    if client.suzerain_id == "": continue
    dom = client.dominant_faction()
    if dom == null: continue
    if dom.tension > REVOLT_FACTION_TENSION_THRESHOLD:  # >80
        patron_id = client.suzerain_id
        client.suzerain_id = ""
        rel = dm.get_or_create_relation(state, client.id, patron_id)
        rel.military_tension = clamp(rel.military_tension + REVOLT_TENSION_INCREASE, 0..100)  # +30
        dom.tension = max(0, dom.tension - REVOLT_TENSION_RELIEF)  # -40
```

Spójne ze spec 03: "klient akumuluje napięcie frakcji i może zbuntować się jako nowa schizma". Tu nie tworzymy schizmy (to wymaga `SchismManager` rozszerzenia — odłożone) — bunt to po prostu odzyskanie niezależności i ostry wzrost napięcia militarnego.

Ulga frakcji po buncie (-40) modeluje rozładowanie energii społecznej po sukcesie wyzwolenia. Bez tego klient natychmiast po buncie miałby tension >80 i potencjalnie wpadał w schizmę w następnej turze.

---

## Sekcja 4: Sprzężenia z istniejącymi systemami

### Wasalstwo a Sojusz Obronny

Wasalstwo nie tworzy automatycznie sojuszu obronnego w Plan 06. Klient i patron mogą równolegle utrzymywać `RelationState.alliance_active = true`, ale to dwa niezależne mechanizmy. Auto-join klienta do koalicji patrona (spec 03 sek.4) — odłożone do Plan 07.

### Wasalstwo a Koalicje

Patron z aktywnymi klientami nie jest automatycznie celem koalicji ani jej członkiem. `evaluate_coalitions` i `auto_join_allies_to_coalitions` (Plan 05) działają bez zmian, oparte na `military_tension` i `alliance_active`.

### Sobór Wasalny a Sobór Ekumeniczny

Obie funkcje shiftują oś, ale są niezależne:
- `ecumenical_council`: source shiftuje *swoją* oś, dobrowolnie
- `vassal_council`: patron shiftuje oś *klienta*, mimowolnie

Religia może być uczestnikiem obu (jako source ekumenicznego z jedną religią, jako patron wasalnego z drugą).

### Sobór Ludowy a Interdykt

Sobór Ludowy działa wyłącznie defensywnie. Nie blokuje innych akcji (Sobór Wasalny przeciw klientowi, Sojusz Obronny, deklaracja wojny). Spec 03 sek.3 wprost wymienia tylko Interdykt.

---

## Sekcja 5: Stałe (pełna lista)

### `Religion`/`RelationState` defaults

```
Religion.resources = 0
Religion.suzerain_id = ""
Religion.interdict_immunity_until = 0
RelationState.vassal_council_cooldown_until = 0
```

### `DiplomacyManager` — nowe stałe (Plan 06)

```
# Zasoby
PASSIVE_INCOME_PER_TURN = 5            # bazowy dochód wszystkich religii
TRIBUTE_PER_TURN = 3                   # przepływ klient → patron

# Uznanie Zwierzchnictwa
SUZERAINTY_DOGMATYZM_BLOCK = 80.0      # A ≥ 80 blokuje (Dogmatyzm >80)
SUZERAINTY_TRUST_THRESHOLD = 40.0      # trust > 40 wymagane
SUZERAINTY_PATRON_PRESTIGE_GAIN = 20   # one-time bonus
SUZERAINTY_ECON_GAIN = 20.0            # one-time bonus

# Bunt
REVOLT_FACTION_TENSION_THRESHOLD = 80.0  # tension dominującej frakcji
REVOLT_TENSION_INCREASE = 30.0           # military_tension patron↔klient
REVOLT_TENSION_RELIEF = 40.0             # spadek tension frakcji po buncie

# Sobór Wasalny
VASSAL_COUNCIL_HIERARCHIA_THRESHOLD = 75.0
VASSAL_COUNCIL_PRESTIGE_COST = 30
VASSAL_COUNCIL_MIN_AXIS_DELTA = 3.0
VASSAL_COUNCIL_MAX_AXIS_DELTA = 8.0
VASSAL_COUNCIL_CLIENT_TENSION_BUMP = 15.0
VASSAL_COUNCIL_COOLDOWN_TURNS = 5

# Sobór Ludowy
PEOPLE_COUNCIL_ROWNOUPRAWNIENIE_THRESHOLD = 30.0  # B < 30
PEOPLE_COUNCIL_PRESTIGE_COST = 15
PEOPLE_COUNCIL_IMMUNITY_TURNS = 5
```

---

## Sekcja 6: Pętle sprzężeń zwrotnych

### Cykl ucisk → bunt

1. Patron (B=80) wymusza serię `[Sobór Wasalny]` na kliencie (+15 tension/użycie, cooldown 5)
2. Klient dominant_faction.tension narasta: 50 → 65 → 80 → 95
3. Tura później `_process_vassal_revolts` wykrywa tension >80 → klient zrywa, `military_tension += 30`
4. Klient ma mocno wrogiego sąsiada (wysokie napięcie) i potencjał na koalicję przeciw patronowi
5. Patron utrzymuje wielu klientów: ryzyko wielu jednoczesnych buntów → izolacja, krucha "imperium"

### Cykl ekonomia trybutu

1. Patron z 3 klientami: dochód +9 resources/turę (poza passive +5)
2. Klient: dochód netto +2/turę (zubożenie, ale stabilne)
3. Klient bez patrona: dochód +5/turę — bardziej opłacalny, ale brak ochrony (out of scope)

### Cykl Sobór Ludowy

1. Religia X (B=20) widzi że sąsiad gromadzi prestiż → ryzyko Interdyktu
2. X wystawia Sobór Ludowy: prestige -15, immunity 5 tur
3. Sąsiad próbuje proclaim_interdict → fail; musi czekać lub atakować innymi środkami
4. Po 5 turach X musi zdecydować: kolejny Sobór (drogo) czy ryzyko Interdyktu

---

## Sekcja 7: Co NIE wchodzi do Plan 06

- **Unia personalna** (nie zdefiniowana w spec 03; przesunięta poza Plan 06)
- **`[Dołącz do potępienia]`** po Interdykcie — wymaga NPC decision system
- **Reaktywny CB `[Rewanż za zniewagę]`** po Interdykcie przy Ekskluzywizm>70 — wymaga integracji z `WarManager.CB_AXIS_REQUIREMENTS`
- **Auto-join klienta do koalicji/sojuszu patrona** — odłożone do Plan 07
- **Bunt klienta tworzący schizmę przez `SchismManager`** — Plan 06 robi tylko "odłączenie", schizma to oddzielne rozszerzenie
- **+5 prestiżu/turę za >10 tur pokoju** — wymaga trackingu `last_conflict_turn`
- **AI NPC inicjujący Uznanie/Sobór Wasalny** — przyszłość
- **UI dyplomacji (akcje gracza)** — dedykowany plan UI
- **Trybut jako zasób inny niż int** (rozszerzony katalog zasobów, np. populacja/wojsko) — Plan 06 wprowadza tylko jedno generic `resources`

---

## Otwarte pytania (poza zakresem Plan 06)

- Czy `Religion.resources` powinno być konsumowane przez inne mechaniki w przyszłości (np. zwerbowanie armii, sponsorowanie misjonarzy)? Plan 06 generuje tylko `resources` — nie ma konsumenta.
- Czy bunt klienta powinien automatycznie zerwać też `alliance_active` patron↔klient (jeśli był)? Obecnie Plan 06 nie ruszamy `alliance_active`.
- Jak Sobór Ludowy współgra z `Sobór Wasalny` (klient z B<30 broni się przed naciskiem patrona z B>75)? Plan 06: Sobór Ludowy blokuje tylko Interdykt — Sobór Wasalny działa niezależnie.
