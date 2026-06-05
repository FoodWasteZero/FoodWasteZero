<div align="center">
  <img src="assets/icon.png" alt="FoodWasteZero" width="80"/>

  # FoodWasteZero 🌱

  **Poveži tiste, ki imajo hrano – s tistimi, ki jo potrebujejo.**

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-enabled-FFCA28?logo=firebase)](https://firebase.google.com)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

  [⬇️ Prenesi APK](https://github.com/FoodWasteZero/FoodWasteZero/actions/runs/26882968684/artifacts/7383949409) · [🐛 Prijavi napako](../../issues) · [💬 Kontakt](#ekipa)

</div>

---

## Kaj je FoodWasteZero?

FoodWasteZero je mobilna aplikacija, ki pomaga zmanjšati količino zavržene hrane. Restavracije, pekarne in posamezniki objavijo presežno hrano — drugi jo prevzamejo brezplačno ali po simbolični ceni, preden konča v smeteh.

> Projekt razvit v sklopu **Praktikum II – FERI 2024/25**

---

## Funkcionalnosti

- 📍 **Oglasi v bližini** — prikaže ponudbe hrane glede na tvojo lokacijo
- 🔔 **Obvestila v realnem času** — takoj izvedi, ko se pojavi nova ponudba
- 📦 **Rezervacija in prevzem** — rezerviraj, prejmi QR kodo, prevzemi
- 🌙 **Temni način** — preklopljiv v nastavitvah, shranjen med sejami
- 👤 **Profil in sledenje** — sledi objavljavcem, pregleduj zgodovino
- 🗺️ **Zemljevid** — vizualni pregled vseh aktivnih oglasov
- 🍽️ **Recepti** — predlogi za hrano, ki jo imaš

---

## Prenesi aplikacijo

**Android APK** (najnovejši build):

👉 [Prenesi APK](https://github.com/FoodWasteZero/FoodWasteZero/actions/runs/26882968684/artifacts/7383949409)

> Za namestitev moraš imeti omogočeno **"Namestitev iz neznanih virov"** v nastavitvah naprave.

---

## Tehnologije

| Plast | Tehnologija |
|-------|-------------|
| Mobilna aplikacija | Flutter (Dart) |
| Backend & Auth | Firebase (Firestore, Auth, Storage) |
| Obvestila | Firebase Cloud Messaging |
| Zemljevid | Google Maps API |
| CI/CD | GitHub Actions |

---

## Namestitev za razvoj

### Predpogoji
- Flutter SDK 3.x
- Firebase CLI
- Android Studio / VS Code

### Koraki

```bash
# 1. Kloniraj repozitorij
git clone https://github.com/FoodWasteZero/FoodWasteZero.git
cd FoodWasteZero

# 2. Namesti odvisnosti
flutter pub get

# 3. Nastavi Firebase
dart pub global activate flutterfire_cli
flutterfire configure

# 4. Dodaj .env datoteko (glej .env.example)
cp .env.example .env

# 5. Zaženi aplikacijo
flutter run
```

---

## Ekipa

| Ime | Vloga |
|-----|-------|
| Julija Anina Medved | |
| Tjaša Jekl | |
| Boris Sajlović | |

---

## Prispevanje

Pull requesti so dobrodošli. Za večje spremembe najprej odpri issue.

```bash
git checkout -b feature/ime-funkcionalnosti
git commit -m "feat: opis spremembe"
git push origin feature/ime-funkcionalnosti
```

---

<div align="center">
  <sub>© 2025 FoodWasteZero · FERI Praktikum II</sub>
</div>*   **70/30 Layout:** Moderni razpored zaslona, ki omogoča interakcijo z AI brez izgube konteksta vsebine.

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
| **Shranjevanje** | Firebase Storage |
| **Zemljevidi** | Google Maps SDK |

---

## Opomba o čakalni vrsti
Cloud Functions niso na voljo, aplikacija uporablja client-side rezervacijsko logiko: naslednji uporabnik v čakalni vrsti se premakne v stanje `rezervirano` z 3-urno potrditvijo, ko nekdo prekliče ali ko poteče predhodna ponudba. Potrditev se izvede v aplikaciji, e-poštni osnutek pa se lahko odpre lokalno prek e-poštnega programa.

---

## 👥 Ekipa in sledenje delu

| Razvijalec | Vloga | Odgovornost |
| :--- | :--- | :--- |
| **[Julija Anina Medved]** |  |
| **[Tjaša Jekl]** |  |
| **[Boris Sajlović]** |  |

---

## Namestitev (Setup)
firebase: namesti flutterfire CLI in flutterfire configure
