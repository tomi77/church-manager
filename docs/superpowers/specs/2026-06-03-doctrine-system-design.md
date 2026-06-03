# Mechanika Systemu Doktryn

**Data:** 2026-06-03
**Projekt:** church-manager
**Status:** Zatwierdzony

---

## Kontekst

Gra typu 4X, w której gracz zarządza religią. Zamiast klasycznego drzewa technologii, doktryna religijna jest reprezentowana przez pozycję na czterech osiach teologicznych. Serce rozgrywki to balansowanie między siłami wewnętrznymi i zewnętrznymi, które nieustannie przesuwają religię w różnych kierunkach.

---

## Sekcja 1: Przestrzeń teologiczna

Religia istnieje jako punkt w 4-wymiarowej przestrzeni osi:

| Oś | Lewy biegun (0) | Prawy biegun (100) |
|----|-----------------|---------------------|
| **A** | Dogmatyzm | Mistycyzm |
| **B** | Hierarchia | Równouprawnienie |
| **C** | Ekskluzywizm | Synkretyzm |
| **D** | Doczesność | Transcendencja |

Punkt startowy zależy od wybranej religii. Przykład:
- Islam: A=70, B=65, C=30, D=75
- Żaden punkt nie jest obiektywnie lepszy — każda pozycja ma bonusy i koszty.

### Efekty pozycji na osiach

**Ciągłe** — każdy punkt na osi daje drobny bonus/karę:
- Przykład: każde +10 Dogmatyzmu = +3% skuteczność misjonarzy, -2% tolerancja lokalna

**Progowe** — po przekroczeniu wartości 75 lub 25 odblokowują się unikalne akcje:

| Próg | Oś | Odblokowana akcja |
|------|-----|-------------------|
| Synkretyzm >75 | C | `[Ekumenizm]`, `[Obrzęd Fuzji]` |
| Ekskluzywizm >75 | C | `[Inkwizycja]`, `[Klątwa]` |
| Dogmatyzm >75 | A | `[Kanon Doktryny]` |
| Mistycyzm >75 | A | `[Objawienie]` |
| Hierarchia >75 | B | `[Papieskie Interdykty]` |
| Równouprawnienie >75 | B | `[Sobór Ludowy]` |

---

## Sekcja 2: Siły przesuwające osie

Religia nigdy nie stoi w miejscu. Cztery siły nieustannie naciskają na osie — często w przeciwnych kierunkach.

### 1. Decyzje gracza — Sobory i Edykty

Aktywna, kosztowna akcja. Gracz zwołuje sobór (koszt: czas + prestiż) i wybiera kierunek zmiany doktryny. Efekt jest duży i natychmiastowy — frakcje niezadowolone z decyzji od razu podnoszą napięcie.

### 2. Presja zewnętrzna — kontakt z innymi religiami

Każda tura spędzona w sąsiedztwie innej religii generuje cichą presję synkretyczną. Im dłuższy kontakt i im więcej wspólnych wiernych, tym silniejsza presja. Gracz może jej aktywnie przeciwdziałać edyktami izolacjonistycznymi lub pozwolić jej działać.

### 3. Wewnętrzne frakcje — kler i wierni

Każda religia ma frakcje z własnymi preferencjami na osiach. Frakcje mają mierzalny **wpływ** (0–100%):
- Im większy wpływ frakcji, tym silniej ciągnie oś w swoim kierunku — pasywnie, co turę
- Zadowolona frakcja wzmacnia stabilność
- Niezadowolona frakcja akumuluje napięcie (patrz: Sekcja 3)

### 4. Kryzysy i objawienia — zdarzenia losowe

Zaraza, klęska żywiołowa, "cud", schizma rywala — każde zdarzenie proponuje decyzję doktrynalną z określonymi konsekwencjami dla osi. Brak decyzji to też wybór (zwykle najgorszy).

---

## Sekcja 3: Schizmy — mechanika eskalacji

Schizma nie jest zdarzeniem losowym. To wynik akumulowanego napięcia frakcji przechodzący przez trzy fazy.

### Wskaźnik Napięcia Frakcji (0–100)

Rośnie gdy:
- pozycja na osi odbiega od preferencji frakcji
- sobór podjął decyzję wbrew frakcji
- kryzys rozwiązano niekorzystnie dla frakcji

Maleje gdy frakcja jest zaspokojona lub gracz wykonuje akcję `[Koncesja]` (koszt: prestiż).

### Faza 1: Ruch heretycki (napięcie >40)

Frakcja organizuje się w widoczny ruch wewnątrz religii. Opcje gracza:

| Akcja | Efekt krótkoterminowy | Efekt długoterminowy |
|-------|----------------------|---------------------|
| `[Stłum]` | -napięcie | -wpływ frakcji, ryzyko nasilenia |
| `[Dialoguj]` | możliwe -napięcie | wymaga ustępstw doktrynalnych |
| `[Ignoruj]` | brak kosztu | napięcie rośnie dalej |

### Faza 2: Odpływ wiernych (napięcie >65)

Wierni odchodzą do innych religii, ateizmu lub stają się "nieaktywni". Każda tura bez rozwiązania to mierzalna utrata wyznawców, z konsekwencjami ekonomicznymi i militarnymi.

### Faza 3: Pełna schizma (napięcie >85)

Jeśli frakcja ma wpływ >30%, odłącza się jako niezależna religia z własną pozycją na osiach — bliska oryginałowi, ale odchylona w kierunku preferencji frakcji.

Relacja ze schizmatycką religią zależy od historii:
- **Wroga** — jeśli schizma była brutalna (stłumienie w fazie 1/2)
- **Rywalska** — neutralna, ale konkurencyjna
- **Potencjalny sojusznik** — jeśli gracz wcześniej dialogował

Schizmę można później wchłonąć przez dyplomację lub podbój, co zamyka pętlę z mechaniką synkretyzmu (Sekcja 4).

---

## Sekcja 4: Wchłanianie doktryn — synkretyzm w praktyce

Trzy ścieżki przejmowania elementów obcych religii, każda dostępna w innym kontekście.

### Ścieżka 1: Uczeni i księgi (zawsze dostępna)

Gracz wysyła uczonego do obcego miasta lub biblioteki. Po kilku turach wraca z `[Ideą]`:

| Decyzja | Efekt |
|---------|-------|
| `[Zaakceptuj]` | przesuwa oś/e, może odblokować akcję, +napięcie frakcji konserwatywnej |
| `[Odrzuć]` | +stabilność frakcji konserwatywnej, brak zmiany doktrynalnej |

Najwolniejsza, ale najbezpieczniejsza ścieżka — działa bez dyplomacji i bez wojny.

### Ścieżka 2: Dyplomacja teologiczna (przy kontakcie pokojowym)

Po wystarczająco długim pokoju z inną religią odblokuje się akcja `[Sobór Ekumeniczny]`. Gracz negocjuje wymianę:
- **Oferuje:** ustępstwo doktrynalne (przesuwa własną oś w kierunku drugiej religii)
- **Zyskuje:** konkretny element doktrynalny lub sojusz

Ryzyko: ustępstwo może niezadowolić własne frakcje konserwatywne.

### Ścieżka 3: Asymilacja po podboju (przy wojnie)

Po zajęciu terytorium wrogiej religii gracz wybiera politykę wobec podbitej ludności:

| Opcja | Efekt natychmiastowy | Efekt długofalowy |
|-------|---------------------|-------------------|
| `[Wypędź]` | czyste terytorium | brak presji, brak zysku doktrynalnego |
| `[Nawracaj]` | powolny przyrost wiernych | zero synkretyzmu |
| `[Zasymiluj]` | przejęcie elementu doktrynalnego | presja synkretyczna rośnie |

Asymilacja to najszybsza droga do obcych doktryn — ale każda zasymilowana populacja to potencjalne napięcie frakcyjne.

### Wpływ pozycji na osi C

- **Synkretyzm >75:** odblokowuje skuteczniejsze wersje wszystkich trzech ścieżek
- **Ekskluzywizm >75:** blokuje dyplomację ekumeniczną, wzmacnia skuteczność nawracania po podboju

---

## Sekcja 5: Spójność systemu

### Przykładowy łańcuch zdarzeń

1. Gracz podbija region z chrześcijańską ludnością → `[Zasymiluj]` → przejmuje element doktrynalny, oś C: 40→52
2. Frakcja konserwatywna (preferuje Ekskluzywizm) podnosi napięcie: 30→48 → **Faza 1: ruch heretycki**
3. Gracz ignoruje → zaraza uderza w prowincję → zdarzenie proponuje "modlitwy przebłagalne" (oś D +8) → gracz akceptuje
4. Frakcja mistyczna zadowolona, napięcie spada → ale frakcja doczesna teraz niezadowolona
5. Uczony wraca z Kordoby z filozofią arystotelesowską → `[Zaakceptuj]` odblokuje Scholastykę, naciska oś A

Gracz nie "buduje drzewko" — reaguje na żywy organizm.

### Pętle sprzężeń zwrotnych

| Sytuacja | Konsekwencja | Kontrposunięcie |
|----------|-------------|-----------------|
| Wysoki Synkretyzm + sąsiednia religia | presja zewnętrzna przyspiesza | edykt izolacjonistyczny |
| Silna frakcja mistyków + dogmatyczny kurs | napięcie eskaluje szybko | koncesja lub stłumienie |
| Schizma → nowa religia | nowy rywal z podobną bazą wiernych | wchłonięcie przez ekumenizm |
| Wielokrotna asymilacja | wiele frakcji z różnymi preferencjami | celowy sobór resetujący kierunek |

### Strategiczna tożsamość religii

Po kilkudziesięciu turach każda rozgrywka generuje unikatową religię — nie przez wybór z listy cech, ale przez historię decyzji, kryzysów i kontaktów. Dwie rozgrywki islamem mogą dać zupełnie różne wyznania.

**Propozycja wartości:** nie zarządzasz statystykami — piszesz historię teologiczną.

---

## Otwarte pytania do dalszego projektowania

- Jak dokładnie działa mapa i terytoria? (system prowincji vs. heksy)
- Jak mechanika wojen łączy się z doktryną? (np. "dżihad" jako akcja progowa)
- Jakie są startowe profile dla judaizmu, chrześcijaństwa, islamu?
- Ile frakcji ma każda religia i jak są generowane?
- Czy gracz może tworzyć własne frakcje?
