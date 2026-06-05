# Mechanika Systemu Dyplomacji

**Data:** 2026-06-04
**Projekt:** church-manager
**Status:** Zatwierdzony
**Powiązane:** [system doktryn](01-doctrine-system-design.md), [system wojen](02-war-system-design.md)

---

## Kontekst

Dyplomacja pełni trzy role jednocześnie: jest narzędziem zapobiegania wojnie (sojusze, redukcja wskaźnika zagrożenia), ścieżką doktrynalnej wymiany (sobory ekumeniczne, misjonarze — alternatywa dla podboju) oraz mechaniką zarządzania prestiżem i koalicjami (geopolityka religijna). Każda akcja dyplomatyczna ma koszt doktrynalny — dyplomacja otwarta przyspiesza dryfowanie na osiach, izolacja odcina wszystkie ścieżki poza wojną.

---

## Sekcja 1: Trzy Wskaźniki Relacji

Każda para religii (gracz ↔ NPC) ma trzy niezależne wskaźniki w zakresie 0–100:

| Wskaźnik | Co mierzy | Rośnie przez | Maleje przez |
|----------|-----------|--------------|--------------|
| **Zaufanie teologiczne** | bliskość doktrynalna i historia dialogu | sobory ekumeniczne, misjonarze wymienni, podobne pozycje na osiach | ekskomuniki, inkwizycja skierowana w ich kierunku, schizma |
| **Współpraca ekonomiczna** | wymiana zasobów i wspólne prowincje | traktaty handlowe, trybut przyjęty pokojowo, długi pokój | grabież prowincji, embargo, odmowa tranzytu |
| **Napięcie militarne** | historia konfliktów i groźb | wypowiedzenie wojny, interdykt, agresja na wspólnych sąsiadów | traktaty pokojowe, mijający czas bez konfliktu, sojusz obronny |

Trzy wskaźniki działają niezależnie — można mieć Zaufanie teologiczne 80 przy Napięciu militarnym 70 (admiracja doktrynalna przy rozwijającym się konflikcie granicznym).

### Progi progowe

| Wskaźnik | Próg | Efekt |
|----------|------|-------|
| Zaufanie teologiczne | >60 | odblokowany `[Sobór Ekumeniczny]` |
| Współpraca ekonomiczna | >50 | odblokowany `[Sojusz Handlowy]` |
| Napięcie militarne | >70 | automatyczny CB `[Rewanż]` dla strony poszkodowanej |
| Napięcie militarne | >85 | blokuje wszystkie akcje teologiczne i ekonomiczne |

---

## Sekcja 2: Akcje Dyplomatyczne

### `[Sobór Ekumeniczny]`

| Element | Wartość |
|---------|---------|
| Wymagania | Zaufanie teologiczne >60, Synkretyzm >40, brak aktywnej wojny |
| Koszt | 30 prestiżu |
| Mechanika | Gracz oferuje ustępstwo doktrynalne (oś przesuwa się o 3–8 pkt w kierunku drugiej religii), w zamian zyskuje element doktrynalny lub trwały bonus |
| Efekt na wskaźniki | Zaufanie teologiczne +15, Napięcie militarne -10 |

### `[Misjonarze Wymienni]`

| Element | Wartość |
|---------|---------|
| Wymagania | Zaufanie teologiczne >30 |
| Koszt | 10 prestiżu |
| Mechanika | Obie strony wysyłają po jednym misjonarzu. Po 3 turach każdy wraca z `[Ideą]` z obcej religii — gracz decyduje `[Zaakceptuj]` / `[Odrzuć]` jak w systemie uczonych |
| Efekt na wskaźniki | Zaufanie teologiczne +10 (obie strony) |
| Ryzyko | Przy Ekskluzywizmie >70: własna frakcja konserwatywna podnosi napięcie o 8–12 |

### `[Sojusz Obronny]`

| Element | Wartość |
|---------|---------|
| Wymagania | Zaufanie teologiczne >50 LUB Współpraca ekonomiczna >60 |
| Koszt | 20 prestiżu |
| Mechanika | Atak na jednego = casus belli `[Obrona sojusznika]` dla drugiego. Sojusz trwa do zerwania lub do własnej agresji |
| Efekt na wskaźniki | Napięcie militarne z sojusznikiem -15, Wskaźnik zagrożenia gracza -10 globalnie |
| Ryzyko | Jeśli sojusznik wypowiada wojnę — gracz dostaje propozycję `[Dołącz]` / `[Zerwij sojusz]` |

### `[Uznanie Zwierzchnictwa]`
*(relacja asymetryczna: mniejsza religia → większa)*

| Strona | Efekt |
|--------|-------|
| Patron (gracz lub NPC) | +20 prestiżu, Współpraca ekonomiczna +20, prawo do `[Soboru Wasalnego]` |
| Klient | ochrona przez sojusz obronny patrona, stały dochód zasobów, utrata niezależności doktrynalnej |
| Ryzyko | Jeśli patron zażąda zbyt wiele — klient akumuluje napięcie frakcji i może zbuntować się jako nowa schizma |

### `[Interdykt Dyplomatyczny]`

| Element | Wartość |
|---------|---------|
| Wymagania | brak — dostępny zawsze |
| Koszt | 15 prestiżu |
| Mechanika | Oficjalne potępienie religii: ich Wskaźnik zagrożenia +15, inne religie dostają propozycję `[Dołącz do potępienia]` za bonus prestiżu |
| Efekt na wskaźniki | Napięcie militarne z potępioną religią +20, Zaufanie teologiczne z nią -25 |
| Ryzyko | Przy Ekskluzywizmie >70 potępionej religii: automatycznie generuje CB `[Rewanż za zniewagę]` |

---

## Sekcja 3: Interakcja z Doktryną

### Twarde blokady

| Warunek doktrynalny | Zablokowana akcja | Uzasadnienie |
|---------------------|-------------------|--------------|
| Ekskluzywizm >80 | `[Sojusz Obronny]` z religią o Synkretyzmie >60 | doktryna wyklucza sojusz z "heretykami" |
| Ekskluzywizm >80 | `[Misjonarze Wymienni]` | obca wiara nie może wchodzić do własnych prowincji |
| Napięcie militarne >85 | `[Sobór Ekumeniczny]`, `[Misjonarze Wymienni]` | quasi-stan wojenny wyklucza dialog |
| Dogmatyzm >80 | `[Uznanie Zwierzchnictwa]` jako klient | doktryna zabrania podporządkowania obcemu autorytetowi |

### Modyfikatory

| Oś | Wartość | Efekt na dyplomację |
|----|---------|---------------------|
| Synkretyzm >60 | +20% | wzrost Zaufania teologicznego ze wszystkich akcji teologicznych |
| Synkretyzm >75 | +35% | j.w. + odblokowane skuteczniejsze wersje Soboru Ekumenicznego |
| Hierarchia >60 | -20% | koszt prestiżu wszystkich akcji dyplomatycznych |
| Hierarchia >75 | dostęp | `[Sobór Wasalny]` — wymuszenie zmiany doktrynalnej u klienta |
| Transcendencja >65 | +15% | siła militarna w `[Sojuszu Obronnym]` |
| Dogmatyzm >70 | -50% | skuteczność obcych misjonarzy u siebie |
| Równouprawnienie >70 | dostęp | `[Sobór Ludowy]` może blokować `[Interdykt Dyplomatyczny]` |

### Sprzężenia z systemem wojennym

| Wskaźnik relacji | Efekt w wojnie |
|------------------|----------------|
| Współpraca ekonomiczna >50 z sojusznikiem | +10% zasoby mobilizacyjne przy `[Sojuszu Obronnym]` |
| Zaufanie teologiczne >70 z uczestnikami Krucjaty/Dżihadu | odłamy chętniej dołączają (-10 do progu akceptacji) |
| Napięcie militarne >70 z sąsiadem | sąsiad rozważa koalicję przy Wskaźniku zagrożenia >40 (próg niższy o 10) |

---

## Sekcja 4: Koalicje i Prestiż

### Mechanika koalicji obronnych

**Warunki powstania:**

| Warunek | Wartość |
|---------|---------|
| Wskaźnik zagrożenia agresora | >50 |
| Napięcie militarne potencjalnego członka z agresorem | >40 |
| Minimalna liczba członków | 2 religie |

Gdy warunki są spełnione, każda kwalifikująca się religia dostaje propozycję `[Dołącz do koalicji]`. NPC akceptuje lub odrzuca na podstawie własnych wskaźników relacji z agresorem i pozostałymi członkami.

**Siła koalicji** to suma sił militarnych wszystkich uczestników — analogicznie do Krucjaty/Dżihadu po stronie obronnej.

**Rozpad koalicji:**
- Wskaźnik zagrożenia agresora spada poniżej 30
- Agresor zawiera pokój z jednym z członków
- Po 5 turach bez aktywnego konfliktu

**Dyplomacja a skład koalicji:**

| Wcześniejsza relacja | Efekt na koalicję |
|----------------------|-------------------|
| Sojusz Obronny z potencjalnym członkiem | automatycznie dołącza bez propozycji |
| Zaufanie teologiczne >60 z potencjalnym członkiem | +20% szansa akceptacji propozycji |
| Interdykt Dyplomatyczny wystawiony przez agresora | wszyscy potępieni automatycznie rozważają koalicję |
| Uznanie Zwierzchnictwa (klient agresora) | klient może zerwać relację i dołączyć do koalicji przy napięciu >60 |

---

### Prestiż jako waluta dyplomatyczna

**Źródła prestiżu:**

| Źródło | Wartość |
|--------|---------|
| Zwycięstwo militarne | +20–50 |
| Uznanie Zwierzchnictwa (jako patron) | +20 |
| Udana Krucjata/Dżihad | +80–150 |
| Sobór Ekumeniczny zaakceptowany przez obie strony | +15 |
| Długi pokój (>10 tur bez konfliktu) | +5 / turę |

**Koszty prestiżu:**

| Wydatek | Koszt |
|---------|-------|
| Sobór Ekumeniczny | 30 |
| Sojusz Obronny | 20 |
| Sobór Pokojowy (redukcja zmęczenia wojennego) | 25 |
| Interdykt Dyplomatyczny | 15 |
| Koncesja dla frakcji | 15 |
| Misjonarze Wymienni | 10 |

**Progi prestiżu — efekty globalne:**

| Próg | Efekt |
|------|-------|
| >500 | warunek do ogłoszenia Krucjaty/Dżihadu |
| >300 | inne religie częściej przyjmują propozycje dyplomatyczne (+15% akceptacja) |
| <100 | NPC-religie ignorują propozycje pokojowe, mogą inicjować interdykty |
| <50 | frakcja wojownicza wewnętrznie traci zaufanie do przywódcy |

---

## Sekcja 5: Spójność Systemu

### Pętle sprzężeń zwrotnych

| Sytuacja | Konsekwencja | Efekt na doktrynę |
|----------|-------------|-------------------|
| Wysoki Synkretyzm + aktywne misjonarze wymienni | Zaufanie teologiczne rośnie szybko, presja synkretyczna przyspiesza | frakcja konserwatywna napięta, ryzyko schizmy |
| Ekskluzywizm >80 + sąsiednie religie | blokada wszystkich akcji teologicznych → jedyna ścieżka to wojna lub izolacja | doktryna pcha w stronę obowiązkowych wojen |
| Długi sojusz obronny + Sobory Ekumeniczne | Zaufanie teologiczne bardzo wysokie → obie religie zbliżają się na osiach | możliwa fuzja lub unia pod zwierzchnictwem |
| Interdykt + wysoki Wskaźnik zagrożenia | koalicja obronna zawiązuje się szybko | agresor izolowany, może rozbijać koalicję prestiżem |
| Uznanie Zwierzchnictwa + zaniedbany klient | klient akumuluje napięcie → zrywa i dołącza do koalicji wrogów | nowa schizma lub wróg z dostępem do wewnętrznych prowincji |

### Przykładowy łańcuch zdarzeń

1. Gracz (islam, Ekskluzywizm 55) podpisuje `[Misjonarze Wymienni]` z chrześcijaństwem → Zaufanie teologiczne: 20→35
2. Frakcja konserwatywna: napięcie 25→37
3. Po 4 turach Zaufanie teologiczne: 35→50 → odblokowany `[Sobór Ekumeniczny]`
4. Sobór: islam przesuwa oś D +6, zyskuje element doktrynalny → Synkretyzm: 40→48
5. Frakcja konserwatywna: napięcie 37→52 → **Faza 1: ruch heretycki**
6. Sąsiedni hinduizm ogłasza Dżihad → Wskaźnik zagrożenia islamu rośnie
7. Chrześcijaństwo proponuje `[Sojusz Obronny]` — gracz akceptuje → Wskaźnik zagrożenia -10
8. Hinduizm: Wskaźnik zagrożenia >50 → chrześcijaństwo automatycznie dołącza do koalicji (Sojusz Obronny)
9. Hinduizm wycofuje Dżihad → Sojusz pozostaje aktywny, Zaufanie teologiczne nadal rośnie
10. Frakcja konserwatywna: napięcie 52→68 → **Faza 2: odpływ wiernych**
11. Gracz stoi przed wyborem: `[Stłum]` frakcję i zerwij sojusz, czy zaakceptuj dryfowanie w stronę Synkretyzmu

Gracz wygrał dyplomatycznie — i stracił kontrolę nad własną doktryną.

### Propozycja wartości

Dyplomacja nie jest narzędziem pokoju — jest **wyborem kosztu**. Każdy sojusz i każdy sobór przesuwa religię. Izolacja jest doktrynalnie bezpieczna, ale militarnie śmiertelna. Otwartość buduje sojusze, ale przyspiesza dryfowanie doktrynalne. Gracz nieustannie rozstrzyga: czysta tożsamość czy przeżycie.

---

## Otwarte pytania do dalszego projektowania

- Jak wygląda inicjatywa NPC-religii? Czy mogą same proponować sojusze i sobory, czy tylko reagują?
- Jak dyplomacja działa w kontekście mapy i prowincji? (wspólne granice vs. religie bez kontaktu geograficznego)
- Czy istnieje dyplomacja wielostronna — traktaty między trzema lub więcej religiami jednocześnie?
- Jak schizmatyckie odłamy dziedziczą relacje dyplomatyczne religii-matki?
