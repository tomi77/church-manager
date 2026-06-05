# Profile Startowe Religii

**Data:** 2026-06-04
**Projekt:** church-manager
**Status:** Zatwierdzony
**Powiązane:** [system doktryn](01-doctrine-system-design.md), [system mapy i prowincji](04-map-province-system-design.md), [system wojen](02-war-system-design.md), [system dyplomacji](03-diplomacy-system-design.md)

---

## Kontekst

Każda religia w grze jest grywalna — od dominujących historycznie (Chrześcijaństwo Zachodnie z prestiżem 500) po niszowe i zagrożone (Manicheizm startujący z 1–2 prowincjami, prześladowany przez wszystkich). Startowy profil religii definiuje jej teologiczną tożsamość, wewnętrzne frakcje i unikalny mechanizm gry, który daje jej odróżnialną ścieżkę do wygranej.

---

## Sekcja 1: Anatomia profilu religii

Każda religia — grywalna i NPC — ma identyczną strukturę startową.

### Dane startowe

| Pole | Typ | Opis |
|------|-----|------|
| `axes` | `{A, B, C, D}` (0–100) | Pozycja na czterech osiach teologicznych |
| `factions` | lista 3 frakcji | Nazwy historyczne, preferencje osi, % wpływu startowego |
| `trait` | 1 unikalny mechanizm | Pasywny modyfikator lub unikalna akcja |
| `prestige_start` | int | Prestiż na początku gry |
| `holy_sites` | lista province_id | Prowincje definiowane jako święte dla tej religii |
| `stance` | mapa `{religion_id → {theology_trust, economic_cooperation, military_tension}}` | Startowe wskaźniki relacji dyplomatycznych (trzy niezależne, zgodnie ze spec dyplomacji) |

### Frakcje — zawsze 3 per religia

| Pole | Opis |
|------|------|
| `name` | Historyczna nazwa (np. "Ulema", "Sufici") |
| `axis_preference` | Preferowany koniec danej osi |
| `influence_start` | Startowy wpływ 0–100% (suma 3 frakcji = 100%) |
| `tension_start` | Startowe napięcie 0–100 |

### Trait — zasada projektowania

Każdy trait adresuje coś historycznie unikalnego dla danej religii i daje realną ścieżkę wygranej niedostępną dla innych. Niszowe religie dostają traity kompensujące słabszy start — trudniejsza gra, odmienna strategia.

Trait to albo:
- **Pasywny modyfikator** — zmienia wartość liczbową istniejącego mechanizmu
- **Unikalna akcja** — nowa opcja niedostępna dla innych religii

### Globalne parametry bazowe gry

Parametry referencowane przez traity — zdefiniowane tutaj jako bazowe wartości silnika:

| Parametr | Wartość domyślna |
|----------|-----------------|
| Limit aktywnych misjonarzy per religia | 3 jednocześnie |
| Limit równoczesnej absorpcji doktryn | 1 religia na raz |
| Domyślne startowe relacje (pary bez jawnych wartości) | theology_trust=20, economic_cooperation=20, military_tension=20 |

---

## Sekcja 2: Religie na mapie historycznej

Mapa historyczna (Bliski Wschód + basen Morza Śródziemnego, ~45–55 prowincji) zawiera 8 religii startowych. Wszystkie są grywalne.

### ☪ Islam

| Pole | Wartość |
|------|---------|
| A — Dogmatyzm/Mistycyzm | 70 (wyraźny Dogmatyzm) |
| B — Hierarchia/Równoupr. | 65 (Hierarchia — Kalifat) |
| C — Ekskluzywizm/Synkretyzm | 30 (silny Ekskluzywizm) |
| D — Doczesność/Transcendencja | 75 (Transcendencja — umma i ahirat) |
| Prestiż startowy | 300 |
| Święte miasta | Mekka, Jerozolima (pretensja) |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Ulema | Dogmatyzm (A↑), Hierarchia (B↑) | 40% |
| Sufici | Mistycyzm (A↓), Transcendencja (D↑) | 30% |
| Wojownicy Wiary | Ekskluzywizm (C↓), Doczesność (D↓) | 30% |

**Trait: Umma**
Umma zmniejsza modyfikator progu akceptacji odłamów do Dżihadu o dodatkowe −5 (łącznie −15 zamiast domyślnych −10 ze spec dyplomacji, sekcja 3: "Zaufanie teologiczne >70 z uczestnikami"). Efekt: odłamy NPC dołączają chętniej. Jeśli Islam kontroluje Mekkę: każda prowincja islamu globalnie generuje +1 prestiż/turę (pielgrzymki).

---

### ✝ Chrześcijaństwo Wschodnie (Bizancjum)

| Pole | Wartość |
|------|---------|
| A | 60 |
| B | 75 (wysoka Hierarchia — Patriarcha + Cesarz) |
| C | 40 |
| D | 60 |
| Prestiż startowy | 450 |
| Święte miasta | Konstantynopol, Jerozolima (pretensja) |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Patriarchowie | Hierarchia (B↑), Dogmatyzm (A↑) | 45% |
| Hezychazm | Mistycyzm (A↓), Transcendencja (D↑) | 30% |
| Cesarze-Teologowie | Hierarchia (B↑), Doczesność (D↓) | 25% |

**Trait: Cezaropapizm**
Cesarz może zwołać Sobór raz na epokę za darmo (bez kosztu prestiżu). Efekt uboczny: napięcie frakcji przegranej strony jest podwojone.

---

### ✝ Chrześcijaństwo Zachodnie (Rzym)

| Pole | Wartość |
|------|---------|
| A | 65 |
| B | 80 (najwyższa Hierarchia — Papiestwo) |
| C | 35 |
| D | 55 |
| Prestiż startowy | 500 (najwyższy na mapie) |
| Święte miasta | Rzym, Jerozolima (pretensja) |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Papiestwo | Hierarchia (B↑), Dogmatyzm (A↑) | 40% |
| Zakonnicy | Transcendencja (D↑), Mistycyzm (A↓) | 35% |
| Reformatorzy | Równouprawnienie (B↓), centrum osi | 25% |

**Trait: Sukcesja Apostolska**
Gdy jakakolwiek religia (gracz lub NPC) wykonuje akcję `[Uznanie Zwierzchnictwa]` wskazując Chrześcijaństwo Zachodnie jako patrona — klient automatycznie otrzymuje −10% odporności na Synkretyzm (ułatwiona absorpcja doktrynalna przez Rzym). Chrześcijaństwo Zachodnie zyskuje +5 prestiżu za każde nowe Uznanie.

---

### ✡ Judaizm

| Pole | Wartość |
|------|---------|
| A | 75 (najwyższy Dogmatyzm — Tora, Talmud) |
| B | 45 |
| C | 20 (najsilniejszy Ekskluzywizm — lud wybrany) |
| D | 65 |
| Prestiż startowy | 250 |
| Święte miasta | Jerozolima (jedyna, krytyczna) |
| Start | 2–3 rozsiane prowincje w Lewancie — brak ciągłości terytorialnej |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Rabini | Dogmatyzm (A↑), umiarkowana Hierarchia | 50% |
| Ortodoksi | Dogmatyzm max (A↑), Ekskluzywizm max (C↓) | 30% |
| Zeloci | Doczesność (D↓ — odbudowa świątyni) | 20% |

**Trait: Diaspora**
Prowincje utracone przez wojnę lub presję nadal generują +1 prestiż/turę (diaspora). Może zakładać synagogi w obcych prowincjach (koszt: 10 złota) — każda generuje +0,5 presji/turę w tej prowincji.

---

### 🔥 Zoroastryzm

| Pole | Wartość |
|------|---------|
| A | 60 |
| B | 70 (Magi — hierarchia kapłańska) |
| C | 30 |
| D | 70 |
| Prestiż startowy | 350 |
| Święte miasta | Persepolis (+5 prestiżu/turę dla właściciela) |
| Start | Historyczny odwrót — Islam naciera od tury 1 |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Magi Wielcy | Hierarchia (B↑), Dogmatyzm (A↑) | 45% |
| Kapłani Ognia | Transcendencja (D↑), Dogmatyzm (A↑) | 35% |
| Zurwanizm | Mistycyzm (A↓), lekki Synkretyzm (C↑) | 20% |

**Trait: Zmartwychwstanie Saszańskie**
Gdy religia kontroluje mniej niż 5 prowincji — pasywna presja generowana przez prowincje Zoroastryzmu na ich sąsiadów (+1–2/turę ze sąsiedztwa, per spec mapy sekcja 3) jest podwojona. Dodatkowe: kontrola prowincji `persepolis` (province_id) daje +10% do `Modyfikator CB` (per formuła ze spec wojen sekcja 2) we wszystkich kampaniach Zoroastryzmu.

---

### ☥ Koptyjski Kościół

| Pole | Wartość |
|------|---------|
| A | 55 |
| B | 50 (Papież Aleksandryjski + silny monastycyzm) |
| C | 35 |
| D | 70 |
| Prestiż startowy | 200 |
| Święte miasta | Aleksandria |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Papież Aleksandryjski | Hierarchia (B↑), Dogmatyzm (A↑) | 40% |
| Ojcowie Pustyni | Transcendencja (D↑), Mistycyzm (A↓) | 40% |
| Wierni Egipscy | Równouprawnienie (B↓), lekki Synkretyzm | 20% |

**Trait: Pamięć Pustynna**
Unikalna akcja `[Ojciec Pustyni]`: wysyła mnicha do prowincji w odległości do 3 kroków grafu sąsiedztwa — bez wymogu wspólnej granicy. Po 5 turach dodaje +20 presji Koptyjskiego Kościoła do docelowej prowincji jednorazowo (odpowiednik akcji `[Zasymiluj]` +15 ze spec mapy sekcja 3, nieznacznie silniejszy z powodu braku wymogu granicy). Koszt: 15 prestiżu.

---

### ☯ Manicheizm

| Pole | Wartość |
|------|---------|
| A | 40 |
| B | 35 |
| C | 85 (najwyższy Synkretyzm na mapie) |
| D | 80 |
| Prestiż startowy | 100 (najniższy) |
| Święte miasta | brak stałego centrum |
| Start | 1–2 prowincje w Persji; prześladowany przez Zoroastryzm i Islam jednocześnie |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Wybrani | Transcendencja (D↑), Mistycyzm (A↓) | 45% |
| Słuchacze | centrum — pragmatyczny Synkretyzm | 40% |
| Teologowie Gnostyccy | Mistycyzm (A↓), lekki Dogmatyzm | 15% |

**Trait: Synkretyzm Radykalny**
Akcja `[Zaakceptuj Ideę]` nie kosztuje prestiżu. Może absorbować elementy doktrynalne od 2 różnych religii jednocześnie (standard: 1 — patrz globalne parametry bazowe). Każda absorpcja generuje +5 napięcia frakcji Wybranych.

---

### 🌙 Religie Arabskie Przedislamskie

| Pole | Wartość |
|------|---------|
| A | 25 (brak świętego tekstu — tradycja oralna) |
| B | 30 (plemienna egalitarność) |
| C | 55 (umiarkowany Synkretyzm — wielobóstwo) |
| D | 45 |
| Prestiż startowy | 150 |
| Święte miasta | Mekka (kontrolowana od tury 1!) |
| Start | Kontrola Mekki = Islam nie może jej mieć — natychmiastowy konflikt |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Strażnicy Kaaby | Hierarchia (B↑), Doczesność (D↓) | 40% |
| Kapłani Plemienni | Dogmatyzm własny (A↑), Ekskluzywizm plemienny | 35% |
| Kupcy i Wędrowcy | Synkretyzm (C↑), Doczesność (D↓) | 25% |

**Trait: Pluralizm Plemienny**
Misjonarze bez limitu liczby (standard: max 3 aktywnych jednocześnie — patrz globalne parametry bazowe). Efekt uboczny: każde zdobycie nowej prowincji ma 40% szansę "schizmy plemiennej" — prowincja przyłącza się, ale natychmiast odłącza się jako nowa religia-odłam NPC startująca z tą prowincją jako kolebką. Mechanicznie traktowane jak Faza 3 schizmy (spec doktryn sekcja 3) lecz bez wymogu napięcia frakcji >85 — efekt czysto terytorialny.

---

## Sekcja 3: Religie eurazjatyckie (tryb rozszerzony)

Aktywne przy trybie mapy "Eurazja (od Hiszpanii do Indii)". Cztery dodatkowe religie z pełnymi profilami.

### 🕉 Hinduizm

| Pole | Wartość |
|------|---------|
| A | 50 (wiele szkół, żaden tekst nie dominuje) |
| B | 70 (system kastowy — Brahmanom) |
| C | 45 |
| D | 65 |
| Prestiż startowy | 400 |
| Święte miasta | Varanasi, Bodh Gaya (współdzielona z Buddyzmem) |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Brahmanom | Hierarchia (B↑), Dogmatyzm (A↑) | 45% |
| Mistycy Jogi | Mistycyzm (A↓), Transcendencja (D↑) | 35% |
| Wojownicy-Królowie | Doczesność (D↓), Hierarchia (B↑) | 20% |

**Trait: Dharma i Varna**
Hinduizm ma absolutną immunizację na mechanizm obowiązkowych CB wojennych z doktryny (niezależnie od pozycji na osiach — nawet przy Ekskluzywizmie >80 nie pojawia się Fatwa ani Sobór Wojenny). Każda prowincja pod kontrolą przez 10+ tur: +2 żywność (głęboka integracja z rolnictwem). Próba nawrócenia obcej religii: +20% kosztu presji dla najeźdźcy (system kastowy utrudnia konwersję).

---

### ☸ Buddyzm

| Pole | Wartość |
|------|---------|
| A | 35 |
| B | 40 |
| C | 70 (wysoki Synkretyzm — absorbuje lokalne tradycje) |
| D | 85 (najwyższa Transcendencja — nirwana) |
| Prestiż startowy | 350 |
| Święte miasta | Bodh Gaya (współdzielona z Hinduizmem) |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Sangha | Hierarchia (B↑), Transcendencja (D↑) | 40% |
| Bodhisattwowie | Synkretyzm (C↑), Równouprawnienie (B↓) | 35% |
| Laicy Świeccy | Doczesność (D↓), Równouprawnienie (B↓) | 25% |

**Trait: Środkowa Droga**
Buddyzm ma absolutną immunizację na mechanizm obowiązkowych CB wojennych z doktryny (niezależnie od pozycji na osiach). Unikalna akcja `[Dharma-Yatra]`: pielgrzymi podróżują przez sąsiednie prowincje generując presję w każdej prowincji po trasie między punktem startowym a celem (do 5 kroków grafu sąsiedztwa). Normalny misjonarz generuje presję w jednej prowincji. Koszt: 25 prestiżu.

---

### ⚡ Religie Germańskie

| Pole | Wartość |
|------|---------|
| A | 20 (tradycja oralna, bez świętego tekstu) |
| B | 35 |
| C | 60 |
| D | 50 |
| Prestiż startowy | 150 |
| Święte miasta | Uppsala |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Godowie i Skalowie | Dogmatyzm (A↑), Transcendencja (D↑) | 35% |
| Wodzowie Wojenni | Doczesność (D↓), Ekskluzywizm (C↓) | 40% |
| Kupcy Bałtyccy | Synkretyzm (C↑), Równouprawnienie (B↓) | 25% |

**Trait: Ragnarök**
Gdy religia traci >50% prowincji startowych — wchodzi w tryb `[Zmierzch Bogów]`: `Modyfikator CB` +20% (per formuła ze spec wojen sekcja 2), zmęczenie wojenne rośnie 50% wolniej. Mechanizm dramatycznego zwrotu — ostatni bój przed przekształceniem lub zagładą.

---

### 🌿 Religie Słowiańskie

| Pole | Wartość |
|------|---------|
| A | 20 |
| B | 25 (najbardziej egalitarna religia) |
| C | 65 |
| D | 55 |
| Prestiż startowy | 120 (najniższy w trybie eurazjatyckim) |
| Święte miasta | Święte Gaje (3–4 prowincje, niski prestiż każda) |

**Frakcje:**

| Frakcja | Preferencja osi | Wpływ startowy |
|---------|-----------------|---------------|
| Wolchowie | Mistycyzm (A↓), Transcendencja (D↑) | 35% |
| Kniaziowie | Hierarchia (B↑), Doczesność (D↓) | 40% |
| Kupcy i Rolnicy | Równouprawnienie (B↓), Synkretyzm (C↑) | 25% |

**Trait: Ziemia i Krew**
Prowincje z terenem góry, pustynia lub żyzne generują +1 żywność extra (duchy ziemi). Przy podboju prowincji słowiańskiej przez obcą religię: dodatkowe −10% siły atakującego ponad standardowe modyfikatory terenu.

---

## Sekcja 4: Startowe relacje dyplomatyczne

Każda para religii ma trzy niezależne wskaźniki (zgodnie ze spec dyplomacji): `military_tension`, `theology_trust`, `economic_cooperation`. Wskaźniki startowe są symetryczne — relacja A→B = B→A. Pary bez jawnych wartości startują z domyślnymi (20/20/20).

### Napięcie militarne — Near East (military_tension)

|  | ISL | ChrZ | ChrW | JUD | ZOR | KOP | MAN | ARA |
|--|-----|------|------|-----|-----|-----|-----|-----|
| **ISL** | — | 70 | 65 | 30 | 80 | 40 | 50 | 75 |
| **ChrZ** | 70 | — | 25 | 35 | 30 | 20 | 45 | 25 |
| **ChrW** | 65 | 25 | — | 30 | 45 | 30 | 40 | 20 |
| **JUD** | 30 | 35 | 30 | — | 20 | 25 | 25 | 30 |
| **ZOR** | 80 | 30 | 45 | 20 | — | 15 | 60 | 35 |
| **KOP** | 40 | 20 | 30 | 25 | 15 | — | 20 | 15 |
| **MAN** | 50 | 45 | 40 | 25 | 60 | 20 | — | 20 |
| **ARA** | 75 | 25 | 20 | 30 | 35 | 15 | 20 | — |

### Zaufanie teologiczne — Near East (theology_trust)

|  | ISL | ChrZ | ChrW | JUD | ZOR | KOP | MAN | ARA |
|--|-----|------|------|-----|-----|-----|-----|-----|
| **ISL** | — | 10 | 15 | 25 | 5 | 20 | 5 | 5 |
| **ChrZ** | 10 | — | 40 | 10 | 15 | 30 | 5 | 10 |
| **ChrW** | 15 | 40 | — | 15 | 20 | 20 | 5 | 10 |
| **JUD** | 25 | 10 | 15 | — | 35 | 30 | 15 | 20 |
| **ZOR** | 5 | 15 | 20 | 35 | — | 15 | 10 | 10 |
| **KOP** | 20 | 30 | 20 | 30 | 15 | — | 15 | 15 |
| **MAN** | 5 | 5 | 5 | 15 | 10 | 15 | — | 20 |
| **ARA** | 5 | 10 | 10 | 20 | 10 | 15 | 20 | — |

Współpraca ekonomiczna (`economic_cooperation`) startuje na 20 dla wszystkich par Near East, chyba że jawnie wskazano inaczej.

### Gorące konflikty (military_tension >60)

| Para | Napięcie | Uzasadnienie |
|------|----------|--------------|
| ZOR ↔ ISL | 80 | Islam podbija Persję — Zoroastryzm walczy o przetrwanie |
| ARA ↔ ISL | 75 | Islam chce Mekki, która od tury 1 należy do Religii Arabskich |
| ChrZ ↔ ISL | 70 | Przyszłe Krucjaty — napięcie obecne od początku |
| ChrW ↔ ISL | 65 | Trwające bitwy arabsko-bizantyjskie |
| MAN ↔ ZOR | 60 | Mani zamordowany przez Zoroastrian — historyczna wrogość |

### Naturalne sojusze (theology_trust >25)

| Para | Zaufanie teologiczne | Uzasadnienie |
|------|----------------------|--------------|
| ChrZ ↔ ChrW | 40 | Jeszcze jedno chrześcijaństwo — Wielka Schizma dopiero nadchodzi |
| JUD ↔ ZOR | 35 | Żydzi perscy mieli dobre stosunki z Sasanidami historycznie |
| KOP ↔ ChrZ | 30 | Heretycki z perspektywy Rzymu, ale nadal chrześcijański |
| KOP ↔ JUD | 30 | Koegzystencja w Egipcie — wspólna historia |
| ISL ↔ JUD | 25 | Status "Ludów Księgi" — dhimmi, napięcie niskie ale zaufanie ograniczone |

Manicheizm: theology_trust 5–20 z każdą religią, military_tension 20–60 — izolowany i prześladowany przez wszystkich.

### Religie eurazjatyckie — relacje startowe

Hinduizm, Buddyzm, Religie Germańskie i Słowiańskie startują z domyślnymi relacjami neutralnymi względem religii Near East (napięcie 20, zaufanie 20, współpraca 20). Wyjątki:

| Para | military_tension | theology_trust | economic_cooperation | Uzasadnienie |
|------|-----------------|----------------|---------------------|--------------|
| BUD ↔ HIN | 35 | 25 | 30 | Konkurencja o prowincje subkontynentu, ale wspólne szlaki handlowe |
| GER ↔ ChrZ | 40 | 15 | 20 | Chrystianizacja Germanii jako cel Kościoła Zachodniego |
| SŁO ↔ ChrW | 40 | 15 | 20 | Chrystianizacja Słowian przez Bizancjum |

---

## Tabela trudności startowej

| Religia | Prestiż | Trudność | Specyfika gry |
|---------|---------|----------|---------------|
| Chrześcijaństwo Zachodnie | 500 | ★★★★★ łatwy | Dominacja hierarchiczna, prestiż jako waluta |
| Chrześcijaństwo Wschodnie | 450 | ★★★★ | Balans między Cesarzem a Kościołem |
| Hinduizm | 400 | ★★★★ | Powolna, stabilna — siła przez trwałość |
| Islam | 300 | ★★★ | Otoczony wrogami, ekspansja albo dyplomacja |
| Zoroastryzm | 350 | ★★★ | Start w odwrocie, trait przetrwania |
| Buddyzm | 350 | ★★★ | Ekspansja przez handel, nie wojnę |
| Judaizm | 250 | ★★ | Diaspora jako strategia, nie słabość |
| Koptyjski Kościół | 200 | ★★ | Projekcja bez granic dzięki Ojcom Pustyni |
| Religie Germańskie | 150 | ★ | Agresywna ekspansja lub dramatyczny upadek |
| Religie Arabskie | 150 | ★ | Obrona Mekki + chaotyczna ekspansja plemienna |
| Religie Słowiańskie | 120 | ★ | Najlepsza obrona terytorialna, najtrudniejszy start |
| Manicheizm | 100 | ★ najtrudniejszy | Unikalny — absorbuj wszystkich, przeżyj sam |

---

## Otwarte pytania do dalszego projektowania

*(Poniższe wymagają rozstrzygnięcia przed implementacją — nie blokują planowania, ale wpływają na warunki zwycięstwa i mechanikę schizmy)*

- Czy Chrześcijaństwo Wschodnie i Zachodnie mogą się zjednoczyć przez dyplomację (odwrócenie Schizmy)? Jeśli tak — wymaga dodatkowej akcji dyplomatycznej w spec dyplomacji.
- Jak działa mechanika schizmy gdy Islam się rozdziela na Sunnizm i Szyizm? Czy odłam dziedziczy profil startowy Islamu z modyfikacjami, czy tworzy zupełnie nowy profil?
- Warunek zwycięstwa Manicheizmu (propozycja): osiągnięcie C>90 oraz wchłonięcie elementów doktrynalnych od co najmniej 4 różnych religii — do zatwierdzenia w osobnej spec warunków zwycięstwa.
- Religie Arabskie → Islam: jeśli religia osiągnie C<30 i A>65, dostępna jest jednorazowa akcja `[Przyjęcie Islamu]` konwertująca ją do Islamu jako gracza. Wymaga spec warunków konwersji religii.
