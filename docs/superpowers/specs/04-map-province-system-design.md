# Mechanika Systemu Mapy i Prowincji

**Data:** 2026-06-04
**Projekt:** church-manager
**Status:** Zatwierdzony
**Powiązane:** [system doktryn](2026-06-03-doctrine-system-design.md), [system wojen](2026-06-04-war-system-design.md), [system dyplomacji](2026-06-04-diplomacy-system-design.md)

---

## Kontekst

Mapa pełni rolę żywego organizmu doktrynalnego — każda prowincja graniczna to zegar odliczający do zmiany tożsamości religii. System prowincji jest szkieletem, na którym opierają się wszystkie trzy mechaniki: doktryna (presja synkretyczna), wojna (sąsiedztwo jako warunek CB), dyplomacja (kontakt geograficzny jako warunek akcji). Gra oferuje dwa tryby mapy do wyboru przez gracza: historyczny (Bliski Wschód) i proceduralny (losowany).

---

## Sekcja 1: Model prowincji i typy terenu

### Model danych prowincji

Każda prowincja to węzeł grafu abstrakcyjnych regionów z nazwami (Anatolia, Egipt, Lewant). Brak siatki heksów — sąsiedztwo to lista połączeń w grafie.

| Pole | Typ | Opis |
|------|-----|------|
| `id` | string | unikalna nazwa (np. `anatolia`, `jerozolima`) |
| `owner` | religion_id | aktualny właściciel |
| `pressure` | map\<religion_id, 0–100\> | presja każdej obcej religii osobno |
| `population` | int | liczba wiernych (wpływa na siłę militarną i dochód) |
| `resources` | `{food, gold}` | dochód per tura |
| `terrain` | enum | jeden z pięciu typów (tabela niżej) |
| `neighbors` | \[\]province_id | lista sąsiednich prowincji w grafie |
| `is_holy_site` | bool | Jerozolima, Mekka, Rzym — pasywnie +3 prestiżu/turę właścicielowi |

### Typy terenu

| Terrain | Modyfikator militarny | Modyfikator ekonomiczny |
|---------|-----------------------|------------------------|
| `plains` (równina) | brak | brak |
| `mountains` (góry) | −15% siła atakującego | −1 żywność/turę |
| `desert` (pustynia) | −10% siła atakującego | −1 żywność, +1 złoto (szlaki handlowe) |
| `coast` (wybrzeże) | brak | +2 złoto (handel morski) |
| `fertile` (żyzne) | brak | +2 żywność, szybszy wzrost populacji |

Święte Miasto (`is_holy_site`) jest naturalnym celem CB `[Krucjaty]` i `[Dżihadu]` — posiadanie go zmienia układ sił globalnie.

---

## Sekcja 2: Sąsiedztwo i kontakt

Graf sąsiedztwa to szkielet całej gry — decyduje o tym, co jest możliwe między prowincjami i ich właścicielami.

### Co wynika z bezpośredniego sąsiedztwa

| Relacja prowincji | Efekt mechaniczny |
|-------------------|-------------------|
| Dwie prowincje różnych religii są sąsiadami | pasywna presja aktywna między nimi |
| Religia A graniczy z prowincją religii B | religia A ma `[Kontakt]` z B → dostęp do akcji dyplomatycznych |
| Brak wspólnej granicy | brak kontaktu → dyplomacja zablokowana, brak pasywnej presji |
| Prowincja neutralna między dwiema religiami | blokuje presję między nimi, sama ją absorbuje |

### Kontakt jako warunek dyplomatyczny

| Akcja dyplomatyczna | Wymaganie geograficzne |
|---------------------|----------------------|
| `[Misjonarze Wymienni]`, `[Sojusz Obronny]`, `[Sobór Ekumeniczny]` | wspólna granica lub co najwyżej jedna prowincja pośrednia |
| `[Interdykt Dyplomatyczny]` | brak — potępienie może dotyczyć odległej religii |
| `[Uznanie Zwierzchnictwa]` | brak — relacja hierarchiczna, nie geograficzna |

### CB wojenne a sąsiedztwo

Atak jest możliwy tylko na prowincję bezpośrednio sąsiadującą z jedną z prowincji atakującego. Kampania (2–4 etapy) może przesuwać się głębiej w terytorium wroga — ale punkt wejścia musi leżeć na granicy.

### Prowincje neutralne

Terytoria pogańskie nie mają właściciela — nie generują presji, nie wchodzą w koalicje, nie wymagają CB do ataku. Są wolną przestrzenią ekspansji. Gdy religia je przejmie, zaczyna generować presję na sąsiadów.

---

## Sekcja 3: Presja — mechanika dwupoziomowa

### Poziom 1: Lokalna presja prowincji (0–100 per obca religia)

Każda prowincja śledzi presję każdej obcej religii osobno — prowincja może mieć presję islamu 60 i chrześcijaństwa 45 jednocześnie.

**Jak rośnie per tura:**

| Źródło | Wartość |
|--------|---------|
| Każda sąsiednia prowincja obcej religii | +1–2 / tura (zależy od populacji sąsiada) |
| Misjonarze obcej religii aktywni w prowincji | +8 / tura |
| Sobór Ekumeniczny z obcą religią | +5 jednorazowo |
| Asymilacja po podboju (`[Zasymiluj]`) | +15 jednorazowo |

**Jak spada:**

| Źródło | Wartość |
|--------|---------|
| Edykt izolacjonistyczny właściciela | −50% do pasywnego przyrostu |
| Dogmatyzm właściciela >70 | −50% skuteczności obcych misjonarzy |
| Własni misjonarze w prowincji (kontra-misja) | −5 / tura presji obcej religii |

**Progi zdarzeń lokalnych:**

| Próg | Zdarzenie |
|------|-----------|
| Presja > 50 | `[Ruch nawróceniowy]` — lokalna frakcja chce zmiany; gracz wybiera `[Stłum]` / `[Dialoguj]` / `[Ignoruj]` |
| Presja > 70 | `[Kryzys prowincji]` — groźba utraty wiernych; co turę bez reakcji: −populacja |
| Presja > 85 | `[Zdarzenie nawrócenia]` — prowincja może zmienić właściciela jeśli gracz nie reaguje 3 tury |

Zdarzenia generuje każda religia przekraczająca próg — gracz może być jednocześnie atakowany przez presję wielu religii.

---

### Poziom 2: Wskaźnik Presji Geograficznej (0–100, globalny)

Agregat stanu wszystkich prowincji gracza:

```
Presja Geograficzna = (suma aktywnych presji we wszystkich prowincjach gracza) / (liczba prowincji × 100) × 100
```

Innymi słowy: średni poziom obcych presji w całym terytorium, normalizowany do 0–100.

**Efekt na oś C (Ekskluzywizm ↔ Synkretyzm):**

| Wskaźnik Presji Geograficznej | Efekt |
|-------------------------------|-------|
| < 20 | brak efektu |
| 20–50 | oś C dryfuje +1 w kierunku Synkretyzmu / 5 tur |
| 51–75 | dryfuje +2 / 5 tur + frakcja konserwatywna zyskuje napięcie |
| > 75 | dryfuje +3 / 5 tur + event `[Oblężenie tożsamości]` — wybór doktrynalny |

To jest mechanizm "presji zewnętrznej" ze specyfikacji doktryn. Gracz z wieloma prowincjami granicznymi nieuchronnie dryfuje ku Synkretyzmowi, chyba że aktywnie kontruje edyktami izolacjonistycznymi.

---

## Sekcja 4: Zmiana właściciela prowincji

Trzy ścieżki zmiany właściciela — każda powiązana z innym systemem.

### Ścieżka 1: Podbój (system wojen)

Prowincja zmienia właściciela natychmiastowo po wygranej kampanii. Gracz wybiera politykę wobec pozostałej ludności:

| Polityka | Efekt na prowincję | Efekt na presję |
|----------|--------------------|-----------------|
| `[Wypędź]` | populacja −80%, brak obcej ludności | czysta prowincja, presja spada do 0 |
| `[Nawracaj]` | populacja rośnie powoli, czysta doktryna | presja poprzedniej religii spada −5/tura |
| `[Zasymiluj]` | populacja natychmiastowa, +element doktrynalny | presja poprzedniej religii +15 jednorazowo, pozostaje |

Podbój prowincji neutralnej nie wymaga CB i nie generuje Napięcia militarnego z nikim — chyba że inna religia rości sobie do niej pretensje.

### Ścieżka 2: Nawrócenie przez presję

Gdy presja obcej religii > 85 przez 3 tury bez reakcji gracza:

1. Losowanie ważone: szansa nawrócenia = `(presja − 70) × 0,8%` per tura
2. Jeśli nawrócenie — prowincja zmienia właściciela na religię o najwyższej presji
3. Gracz dostaje event `[Teologia utraty]` — wybór doktrynalny wyjaśniający utratę prowincji (analogia do `[Teologii klęski]` z systemu wojen)

### Ścieżka 3: Dyplomacja

Prowincja nie zmienia właściciela przez dyplomację — ale może zmienić *status*:

| Akcja | Efekt na prowincje |
|-------|--------------------|
| `[Uznanie Zwierzchnictwa]` | prowincje klienta dostają status `[Zależna]` — patron pobiera zasoby, nie jest właścicielem |
| `[Sobór Wasalny]` (Hierarchia >75) | patron wymusza zmianę doktryny klienta bez zmiany właściciela prowincji |
| Zerwanie `[Uznania Zwierzchnictwa]` | prowincje klienta wracają do pełnej niezależności |

Status `[Zależna]` jest widoczny na mapie — prowincja ma kolor właściciela z ikoną patrona.

---

## Sekcja 5: Tryby mapy i spójność z systemami

### Tryb historyczny — Bliski Wschód

**Stan startowy:**

| Element | Wartość |
|---------|---------|
| Liczba prowincji | ~45–55 |
| Prowincje gracza | historyczne terytorium wybranej religii (np. Islam: Arabia + część Lewantu) |
| Prowincje NPC | pozostałe religie historyczne ze swoimi terytoriami |
| Prowincje neutralne | ~30–40% mapy — terytoria plemienne i pogańskie |
| Święte Miasta | Jerozolima, Mekka, Rzym, Konstantynopol — predefiniowane |

Gracz od tury 1 ma aktywną presję synkretyczną z sąsiadami i kontakt dyplomatyczny z religiami granicznymi. Docelowo rozszerzany do Eurazji (od Hiszpanii do Indii, ~90–130 prowincji).

### Tryb proceduralny

**Generowanie mapy:**

1. Losowana liczba prowincji (konfigurowalnie: 30–80)
2. Graf sąsiedztwa generowany algorytmicznie
3. Każda religia startowa dostaje jedną prowincję `[Kolebkę]` — odległą od innych kolebek o minimum 3 kroki grafu
4. Reszta prowincji neutralna
5. Terrain i zasoby przydzielane losowo z wagami (wybrzeże przy krawędziach, góry w klastrach)
6. Losowo jedna prowincja per religia startowa dostaje `is_holy_site = true`

---

### Pętle sprzężeń zwrotnych

| Sytuacja | Konsekwencja | Efekt na doktrynę |
|----------|-------------|-------------------|
| Wiele prowincji granicznych z różnymi religiami | Wskaźnik Presji Geograficznej rośnie szybko | oś C dryfuje ku Synkretyzmowi bez działania |
| Podbój przez `[Zasymiluj]` wielu prowincji | presja poprzednich właścicieli kumuluje się | frakcja konserwatywna w Fazie 1–2 |
| Utrata prowincji przez nawrócenie | event `[Teologia utraty]` | niezaplanowana zmiana osi |
| Izolacja geograficzna (brak wspólnych granic) | brak kontaktu → brak dyplomacji | doktryna pcha w stronę Ekskluzywizmu |
| Klient `[Uznania Zwierzchnictwa]` z wieloma prowincjami | patron zarabia prestiż pasywnie | patron może szybciej ogłosić Krucjatę |

### Propozycja wartości

Mapa nie jest planszą — jest **żywym organizmem doktrynalnym**. Gracz zarządzający dużym terytorium nieuchronnie dryfuje ku Synkretyzmowi; gracz izolowany zachowuje czystość doktryny, ale traci dostęp do dyplomacji i ekspansji. Geopolityka religijna wymusza wybór: rosnąć i się zmieniać, czy stać w miejscu i przetrwać.

---

## Otwarte pytania do dalszego projektowania

- Jak wygląda interfejs mapy — widok prowincji, panel szczegółów, nakładki (presja, zasoby, napięcie)?
- Czy gracz może prowadzić wojnę domową wewnątrz własnych prowincji (stłumienie schizmy siłą)?
- Jak działają szlaki handlowe między prowincjami wybrzeżowymi?
- Jakie są startowe profile religii — ile prowincji startowych, jakie Święte Miasta?
