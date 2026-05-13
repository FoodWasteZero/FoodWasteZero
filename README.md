# FoodWasteZero
Praktikum II 

> *Moderni app za zmanjševanje zavržene hrane z uporabo umetne inteligence in napredne geolokacije.*
>


[![Framework](https://img.shields.io/badge/Framework-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Backend](https://img.shields.io/badge/Backend-Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)

___

## 🎯 Fokus aplikacije
Aplikacija je optimizirana za hitro kroženje dveh tipov hrane:
1.  **Sestavine:** Osnovna živila, ki so pred iztekom roka (npr. zelenjava, moka, mleko). Ta del napaja našega **AI Kuharja**, ki pomaga uporabnikom načrtovati obroke.
2.  **Pripravljena hrana:** Kuhani obroki iz restavracij ali gospodinjstev, pripravljeni na takojšnjo **rezervacijo in osebni prevzem**.

---
### 📍 Pametna lokacija in logistika
*   **Real-time Map:** Interaktivni zemljevid z bližnjimi objavami hrane (Google Maps API).
*   **Heatmap Analytics:** Vizualni prikaz kritičnih točk z največ hrane za optimizacijo prevzemov.
*   **"Odpelji me" Navigacija:** Takojšnja povezava z Google Maps za najhitrejšo pot do prevzemnega mesta.

### 🆘 Emergency Food Mode
*   **Nujne objave:** Prioritetni oglasi za hrano s kritično kratkim rokom trajanja.
*   **Smart Notifications:** Takojšnje obveščanje uporabnikov o novih izdelkih v radiju 500m preko Firebase Cloud Messaging.

### 🤖 AI Kitchen Assistant (70/30 UI)
*   **AI Kuhar:** Pametni panel, ki predlaga recepte na podlagi trenutno razpoložljive hrane v aplikaciji in/ali iz sestavin, ki jih je uporabnik rezerviral/prevzel
*   **70/30 Layout:** Moderni razpored zaslona, ki omogoča interakcijo z AI brez izgube konteksta vsebine.

### 📊 Eco-Impact Profil
*   **Statistika:** Pregled rešenih kilogramov hrane in števila obrokov.
*   **Gratifikacija:** Sistem značk in nivojev za najbolj aktivne člane skupnosti.

---

## 🎨 Design Language
*   **Eco-Green Palette:** Sveži zeleni odtenki za trajnostni občutek.
*   **Startup Vibe:** Izjemno tekoče animacije in prehodi.
*   **Eco-Animations:** Uporaba Lottie in Rive komponent za premium UX.

---

## 🛠 Tehnološki sklad 

| Komponenta | Tehnologija |
| :--- | :--- |
| **Frontend** | Flutter (Dart) |
| **Baza podatkov** | Cloud Firestore |
| **Avtentikacija** | Firebase Auth |
| **Logika** | Cloud Functions |
| **Shranjevanje** | Firebase Storage |
| **Zemljevidi** | Google Maps SDK |

---

## 👥 Ekipa in sledenje delu

| Razvijalec | Vloga | Odgovornost |
| :--- | :--- | :--- |
| **[Julija Anina Medved]** |  |
| **[Tjaša Jekl]** |  |
| **[Boris Sajlović]** |  |

---

## Namestitev (Setup)

