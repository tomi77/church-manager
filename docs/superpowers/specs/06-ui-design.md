# Projekt Interfejsu Użytkownika

**Data:** 2026-06-04
**Projekt:** church-manager
**Status:** Zatwierdzony
**Powiązane:** [profile religii](05-religion-profiles-design.md), [system dyplomacji](03-diplomacy-system-design.md), [system doktryn](01-doctrine-system-design.md), [system mapy](04-map-province-system-design.md)

---

## Kontekst

Gra działa na trzech platformach: **mobile, web, desktop**. Interfejs jest responsywny — układ i gęstość informacji adaptują się do szerokości ekranu, ale te same zakładki i te same dane są dostępne wszędzie. Technologia implementacji jest jeszcze niezdecydowana; spec jest platform-agnostyczny i opisuje zachowanie, nie framework.

Kluczowy wzorzec responsywności:

| Szerokość ekranu | Tryb |
|---|---|
| < 768 px (mobile) | kompaktowy: mniejszy nagłówek, bottom sheet, lista relacji |
| ≥ 768 px (web / desktop) | rozbudowany: pełny nagłówek, panel boczny, siatka kart |

---

## Sekcja 1: Architektura nawigacji

### Struktura zakładek

Główna nawigacja składa się z **4 zakładek**, dostępnych na każdym ekranie jako stały pasek:

| Zakładka | Ikona | Zawartość |
|---|---|---|
| Mapa | 🗺 | Pseudo-geograficzna mapa prowincji |
| Wiara | 🕌 | Profil teologiczny: osie, trait, doktryny |
| Świat | 🌍 | Dyplomacja z innymi religiami + aktywne wojny |
| Frakcje | 👥 | Trzy wewnętrzne frakcje religii gracza |

Na **mobile** pasek zakładek siedzi na dole ekranu (thumb-friendly). Na **desktop/web** siedzi na górze, pod nagłówkiem.

Alerty (żądania frakcji, dostępne doktryny, CB do deklaracji) sygnalizowane są jako **czerwona kropka** na ikonie zakładki — nie blokują gry, nie wymagają kliknięcia.

---

## Sekcja 2: Nagłówek globalny

Nagłówek jest zawsze widoczny, niezależnie od aktywnej zakładki.

### Mobile — kompaktowy

Jedna linia:

```
[ikona religii] [Nazwa religii]  [Tura N]  [⚑ prestiż]  [Zakończ turę →]
```

Przykład: `☪ Islam  Tura 14  ⚑ 300  Zakończ turę →`

### Desktop/Web — rozbudowany

Dwie linie:

```
[ikona] [Nazwa]  [Tura N]  [⚑ prestiż]  [💰 +X/turę]  [🌾 +Y/turę]  [⚔ N aktywna]  [Zakończ turę →]
```

Wskaźniki w nagłówku desktop:
- `⚑` — aktualny prestiż (liczba)
- `💰` — dochód złota netto za turę
- `🌾` — bilans żywności netto za turę
- `⚔` — liczba aktywnych wojen (czerwony gdy > 0)
- alert `👥 Frakcja: żąda` — pojawia się gdy któraś frakcja ma aktywne żądanie

---

## Sekcja 3: Zakładka Mapa

### Renderowanie mapy

Mapa to **pseudo-geograficzna siatka SVG** z zarysem Bliskiego Wschodu i Eurazji. Prowincje to kolorowe wielokąty (nie węzły-kółka, nie siatka hex). Granica między dwoma wielokątami = sąsiedztwo w grafie prowincji (per spec mapy sekcja 2).

Kolor wielokąta = religia właściciela. Intensywność koloru sygnalizuje poziom presji obcej religii na krawędziach wielokąta według progów:

| Najwyższa obca presja | Efekt wizualny |
|---|---|
| 0–30 | brak zabarwienia |
| 31–60 | delikatny tint obcego koloru na krawędzi |
| 61–85 | wyraźny tint obcego koloru |
| > 85 | pulsujący alert (krawędź miga kolorem wroga) |

Paleta kolorów religii:
| Religia | Kolor wielokąta | Kolor akcentu |
|---|---|---|
| Islam | `#0d3a1a` | `#5aaa5a` |
| Chr. Zachodnie | `#0a0a2a` | `#7a7aff` |
| Chr. Wschodnie | `#0a0a22` | `#6a6aee` |
| Judaizm | `#1a1600` | `#bbaa00` |
| Zoroastryzm | `#1a0d00` | `#cc7a1a` |
| Koptyjski | `#0d1a10` | `#4aaa6a` |
| Manicheizm | `#180818` | `#cc55cc` |
| Rel. Arabskie | `#1a1000` | `#dd9922` |
| Hinduizm | `#1a0808` | `#ee5533` |
| Buddyzm | `#001518` | `#33bbcc` |
| Rel. Germańskie | `#0d1408` | `#88cc44` |
| Rel. Słowiańskie | `#0a1210` | `#55bb88` |

### Panel szczegółów prowincji

Po kliknięciu/tapnięciu prowincji otwiera się panel szczegółów — **adaptacyjnie**:

**Mobile:** bottom sheet wysuwa się z dołu ekranu (50% wysokości). Mapa widoczna w górnej połowie. Swipe w dół zamyka.

**Desktop/Web:** panel boczny wysuwa się z prawej strony (szerokość 280 px). Mapa zwęża się o tę wartość.

Zawartość panelu szczegółów prowincji:

```
[Nazwa prowincji] · [religia właściciela] · [typ terenu] · [★ Święte Miasto]
[populacja: N]  [💰 +X złota/turę]  [🌾 +Y żywności/turę]
─────────────────────────────
Presja religijna:
  ☪ Islam        ████████░░ 72
  ✝ Chr. Zach.   ██░░░░░░░░ 18
─────────────────────────────
Dostępne akcje:
  [⚔ Wypowiedz wojnę]  [📜 Wyślij misjonarza]  [🌍 → Dyplomacja]
```

`[★ Święte Miasto]` pojawia się tylko gdy `is_holy_site = true` (per spec mapy sekcja 1 — Jerozolima, Mekka, Rzym, Konstantynopol). Zasoby (`food`, `gold`) pochodzą z pola `resources` modelu prowincji (spec mapy sekcja 1).

`[🌍 → Dyplomacja]` nie otwiera żadnego okna kontekstowego na poziomie prowincji — przenosi gracza do zakładki Świat z zaznaczoną religią właściciela tej prowincji. Wszystkie akcje dyplomatyczne wykonywane są z poziomu zakładki Świat (per spec dyplomacji sekcja 2).

`[⚔ Wypowiedz wojnę]` i `[📜 Wyślij misjonarza]` są kontekstowe — pojawiają się tylko jeśli warunki są spełnione (sąsiedztwo, dostępne CB, kontakt per spec mapy sekcja 2 i spec wojen).

---

## Sekcja 4: Zakładka Wiara

### Profil teologiczny — wykres radarowy

Centrum zakładki to **wykres radarowy (diament)** z 4 osiami:

```
         A: Dogmatyzm
              ●
             /|\
            / | \
D:Transcend●--+--●B: Hierarchia
            \ | /
             \|/
              ●
         C: Ekskluzywizm
```

Kształt diamentu = sylwetka teologiczna religii. Każdy wierzchołek odpowiada wartości 100 danej osi — im dalej od środka, tym wyższa wartość. Środek = 0, krawędź zewnętrzna = 100. Każde ramię diamentu jest proporcjonalne do wartości liczbowej osi. Niska wartość osi (np. C=30 u Islamu) rysuje krótkie ramię. Siatka pomocnicza: 3 koncentryczne romby (25/50/75).

**Konwencja osi** (per spec doktryn sekcja 1 po korekcie i spec profili religii): wysokie wartości = Dogmatyzm (A), Hierarchia (B), Synkretyzm (C), Transcendencja (D). Wierzchołki diamentu: góra=Dogmatyzm, prawo=Hierarchia, dół=Synkretyzm, lewo=Transcendencja.

Pod wykresem: 4 wartości liczbowe w tabeli (A: 70 · B: 65 · C: 30 · D: 75).

### Unikalny trait

Karta traitu poniżej wykresu:

```
┌─────────────────────────────┐
│ Umma                        │
│ Próg CB Dżihadu obniżony    │
│ o dodatkowe −5 (łącznie −15)│
└─────────────────────────────┘
```

### Doktryny

Lista dostępnych doktryn na dole zakładki:

```
● Obowiązek Zakat           [aktywna]
◐ Ruch Mutazylitów          [dostępna gdy A<75]  [Aktywuj]
○ Suficka Szkoła Prawna     [zablokowana — A>60]
```

Stany doktryny i ich definicje:

| Stan | Kolor | Definicja |
|---|---|---|
| `aktywna` | zielony ● | Doktryna jest włączona i wywiera efekt — gracz ją wcześniej aktywował lub startuje z nią domyślnie |
| `dostępna` | żółty ◐ + [Aktywuj] | Warunek osi spełniony, doktryna nie jest aktywna — gracz może ją aktywować w tej turze |
| `zablokowana` | szary ○ | Warunek osi niespełniony — kliknięcie pokazuje brakujący warunek (np. "wymaga A < 75") |

Jednoczesna aktywacja: per spec doktryn (sekcja 1) maksymalnie 1 absorpcja doktryny naraz — przycisk [Aktywuj] innych doktryn jest nieaktywny gdy trwa absorpcja.

---

## Sekcja 5: Zakładka Frakcje

### Layout

Trzy frakcje wyświetlane w **3 kolumnach poziomych**. Na mobile kolumny są przewijalne poziomo (swipe). Na desktop wszystkie 3 widoczne jednocześnie.

Każda kolumna:

```
┌────────────────┐
│ Sufici         │   ← nazwa frakcji
│ ⚠ rośnie       │   ← status (dominująca / rośnie / słabnie)
│                │
│     30%        │   ← wpływ (duża liczba)
│   wpływ        │
│                │
│ napięcie ████░░ 55│
│                │
│ pref: ↑Mistycyzm│  ← preferencja doktrynalna
│                │
│ ⚠ Żąda:        │  ← żądanie (jeśli aktywne, pomarańczowe tło)
│  ↑ Mistycyzm   │
│  (tura 3)      │
└────────────────┘
```

Kolumna z aktywnym żądaniem ma pomarańczowe obramowanie. Kolumna **dominującej frakcji** (frakcja z najwyższym procentem wpływu spośród trzech; remis → pierwsza na liście w profilu religii) ma zielone obramowanie.

---

## Sekcja 6: Zakładka Świat

### Mobile — lista relacji

Scrollowalna lista. Każdy wiersz:

```
[ikona] [Nazwa religii · 72 px]  [Z ██░ E ██░ N ████]  [akcja/status]
```

Trzy mini-paski (Z = zaufanie teologiczne, E = ekonomia, N = napięcie militarne). Kolory pasków: zaufanie = zielony, ekonomia = złoty, napięcie = czerwony.

Status po prawej:
- `⚔ Aktywna` (czerwony) — trwa wojna
- `CB dostępne` (pomarańczowy) — można wypowiedzieć wojnę
- `Dyplomacja` (niebieski) — dostępne akcje dyplomatyczne
- *(puste)* — brak kontaktu

### Desktop/Web — karty + sekcja wojen

**Górna sekcja** (czerwone tło, zawsze widoczna gdy są aktywne konflikty):

```
⚔ Aktywne konflikty
  🔥 Zoroastryzm · tura 3 · atak Islam    [Negocjuj = Sobór Pokojowy]
```

`[Negocjuj]` odpowiada akcji `[Sobór Pokojowy]` ze spec dyplomacji (sekcja 4, koszt 25 prestiżu) — jest to jedyna mechanika kończąca wojnę przez dyplomację.

**Dolna sekcja** — siatka 2-kolumnowa kart. Każda karta:

```
┌────────────────────┐
│ 🔥 Zoroastryzm     │
│ ⛪ zaufanie  ██░░░ 20│
│ 💰 ekonomia  ██░░░ 20│
│ ⚔ napięcie  ████░ 80│
│ [Wypowiedz wojnę]  │
└────────────────────┘
```

Kliknięcie karty / wiersza listy otwiera panel akcji dyplomatycznych dostępnych dla tej pary (per spec dyplomacji sekcja 2).

---

## Sekcja 7: Podsumowanie tury

Po kliknięciu „Zakończ turę" pojawia się **overlay z 4 kaflami** (nie blokuje pełnego ekranu, można przejść dalej bez czytania):

```
┌─────────────────────────────────────────┐
│ ☪ Islam  Tura 14 → 15                   │
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │ 🗺 Presja │  │👥 Frakcje│            │
│  │   +3     │  │   ! 1    │            │
│  │ Lewant75 │  │ Sufici60 │            │
│  └──────────┘  └──────────┘            │
│  ┌──────────┐  ┌──────────┐            │
│  │🌍 Dyplom.│  │💰 Zasoby │            │
│  │   −5     │  │  +12 zł  │            │
│  │⚔Chr.Z→75│  │ prest.305│            │
│  └──────────┘  └──────────┘            │
│                                         │
│  [📋 Pełne zdarzenia]  [Tura 15 →]     │
└─────────────────────────────────────────┘
```

Kafle są klikalne — rozwijają scrollowaną listę chronologiczną wszystkich zdarzeń danej kategorii z bieżącej tury. Każde zdarzenie na liście zawiera: nazwę zdarzenia, prowincję lub religię której dotyczy, wartość przed i po (np. "Lewant · presja Islam: 72 → 75"). „Pełne zdarzenia" pokazuje wszystkie zdarzenia wszystkich kategorii w jednej chronologicznej liście.

Kolor kafla sygnalizuje stan: zielony (+), czerwony (!), szary (neutralny).

---

## Sekcja 8: Wzorce responsywności

Podsumowanie wszystkich adaptacji mobile ↔ desktop:

| Komponent | Mobile (< 768 px) | Desktop (≥ 768 px) |
|---|---|---|
| Pasek zakładek | dolny, ikona + etykieta | górny, pod nagłówkiem |
| Nagłówek | 1 linia: religia + tura + prestiż | 2 linie: + zasoby + alerty |
| Mapa | pełna szerokość | pełna szerokość |
| Szczegóły prowincji | bottom sheet (50% wys.) | panel boczny (280 px) |
| Wiara — osie | diament + tabela wartości | diament + tabela wartości |
| Frakcje | 3 kolumny, swipe poziomy | 3 kolumny widoczne jednocześnie |
| Świat — dyplomacja | lista z mini-paskami | siatka kart 2-kol. + sekcja wojen |
| Podsumowanie tury | 4 kafle (overlay) | 4 kafle (overlay) |

---

## Pytania otwarte

*(do rozstrzygnięcia przed implementacją)*

1. ~~**Mapa proceduralna**~~ — **ROZSTRZYGNIĘTE:** tryb proceduralny odłożony na przyszły milestone. Pierwszy milestone implementuje wyłącznie mapę historyczną (SVG Bliskiego Wschodu). Planowanie zakładki Mapa może ruszyć bez tego pytania.
2. **Animacje przejść** — czy zmiany presji i przesunięcia granic na mapie są animowane między turami, czy pokazywane jako zmiana statyczna?
3. **Dostępność** — paleta kolorów opiera się na odcieniach (zielony Islam, niebieski Chr. Zach.) — potrzebny wariant dla daltonistów (ikony jako primary differentiator).
4. **Lokalizacja** — nazwy prowincji, religii i doktryn w jednym języku (PL/EN), czy wielojęzyczne?
5. ~~**Kierunek osi teologicznych**~~ — **ROZSTRZYGNIĘTE:** spec doktryn sekcja 1 został zaktualizowany — bieguny osi A i B były odwrócone. Poprawna konwencja (zgodna ze spec profili religii i wszystkimi 12 profilami): A=0=Mistycyzm, A=100=Dogmatyzm; B=0=Równouprawnienie, B=100=Hierarchia. Wierzchołek górny diamentu = Dogmatyzm (A→100), wierzchołek prawy = Hierarchia (B→100).

---

*Spec zatwierdzona — gotowa do planowania implementacji.*
