# <img src="/android/app/src/main/res/mipmap-mdpi/ic_launcher.png" alt="Dorkcoin Wallet Logo" width="28"/> Dorkcoin Android Wallet

<p align="center">
  <img src="/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" alt="Dorkcoin Wallet Logo" width="120"/>
</p>

<p align="center">
  A lightweight, secure, and modern <strong>Flutter-based light wallet</strong> for <strong>Dorkcoin (DORK)</strong> on Android.
</p>

<p align="center">
  <a href="https://github.com/syabiz/dorkcoin-android-wallet/releases"><img src="https://img.shields.io/github/v/release/syabiz/dorkcoin-android-wallet?style=flat-square&color=gold" alt="Latest Release"/></a>
  <a href="https://github.com/syabiz/dorkcoin-android-wallet/blob/main/LICENSE.md"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License"/></a>
  <img src="https://img.shields.io/badge/platform-Android-green?style=flat-square&logo=android" alt="Platform"/>
  <img src="https://img.shields.io/badge/built%20with-Flutter-02569B?style=flat-square&logo=flutter" alt="Flutter"/>
</p>

---

## 📖 Overview

**Dorkcoin Android Wallet** is a mobile light wallet specifically configured for the **Dorkcoin (DORK)** network. It ensures correct address generation (starting with **`D`**) and proper Private Key WIF handling (starting with **`Q`**). All transaction signing is performed **locally on your device** — your keys never leave your hands.

> Forked and adapted from [996-Coin Mobile Client](https://github.com/Hashcash-PoW-Faucet/996-Coin-Mobile-Client) by [Hashcash-PoW-Faucet](https://github.com/Hashcash-PoW-Faucet). Full credit and respect to the original developer for laying the solid groundwork.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔑 **Generate Wallet** | Create a brand-new Dorkcoin address and private key pair locally |
| 📥 **Import Wallet** | Import your existing WIF Private Key |
| 📤 **Export Keys** | Backup your wallet keys securely |
| 💸 **Send & Receive** | Send DORK coins and share your address via QR code |
| 📋 **Transaction History** | View your past transactions fetched directly from the explorer |
| 🔒 **Security** | Locally stored encrypted wallet with biometric/PIN authentication support |
| 📖 **Address Book** | Save and manage frequently used recipient addresses |
| 📷 **QR Scanner** | Scan recipient addresses via camera |
| 🌑 **Modern UI** | Dark-themed gold/yellow design inspired by the Dork Wallet Generator |

---

## ⚙️ Technical Details

| Property | Value |
|---|---|
| **Coin** | Dorkcoin (DORK) |
| **Address Prefix** | `0x1E` → results in address starting with `D` |
| **WIF Prefix** | `0x9E` → results in WIF starting with `Q` |
| **Framework** | Flutter (Dart) |
| **Network** | Dorkcoin MainNet |
| **Backend** | Explorer API (balance, UTXO, history, broadcast) |
| **Signing** | Local — done entirely on-device |

---

## 📲 Installation

### Option A — Download APK (Recommended)

1. Go to the [**Releases**](https://github.com/syabiz/dorkcoin-android-wallet/releases) page.
2. Download the latest `app-release.apk`.
3. Transfer it to your Android device and install it.
4. If prompted, allow **"Install from unknown sources"** in your device settings.

### Option B — Build from Source

#### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Android Studio with Android SDK installed
- A connected Android device or emulator

#### Steps

```bash
# 1. Clone the repository
git clone https://github.com/syabiz/dorkcoin-android-wallet.git
cd dorkcoin-android-wallet

# 2. Fetch dependencies
flutter pub get

# 3. Build the release APK
flutter build apk --release

# 4. (Optional) Build App Bundle for Play Store
flutter build appbundle --release
```

The output APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔐 Security Notes

- **Your private key never leaves your device.** All signing is done locally.
- Always **backup your Private Key / WIF** in a safe, offline location.
- Never share your private key or WIF with anyone.
- The developers are **not responsible** for any loss of funds due to lost keys or improper use.

---

## 🗂️ Project Structure

```
dorkcoin-android-wallet/
├── android/          # Android platform-specific files
├── assets/
│   └── icon/         # App icon assets
├── lib/              # Main Flutter/Dart source code
├── pubspec.yaml      # Project dependencies
└── README.md
```

---

## 🤝 Contributing

This project is open-source and contributions are welcome!

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

Please open an [Issue](https://github.com/syabiz/dorkcoin-android-wallet/issues) first for major changes.

---

## 🏷️ Credits

- **Fork Maintainer**: [syabiz](https://github.com/syabiz) — Dorkcoin adaptation
- **Original Developer**: [Hashcash-PoW-Faucet](https://github.com/Hashcash-PoW-Faucet) — [996-Coin Mobile Client](https://github.com/Hashcash-PoW-Faucet/996-Coin-Mobile-Client)

---

## ☕ Support

If this tool has been helpful to you, perhaps there's a reward of a cup of coffee and a pack of cigarettes for me? 😄

| Network | Address |
|---|---|
| 🤓 Dorkcoin (DORK) | `DGEqDGY8n98YA7LSBVRL7C6Ld9b5gGomU4` |
| ₿ Bitcoin (BTC) | `bc1qn6t8hy8memjfzp4y3sh6fvadjdtqj64vfvlx58` |
| ⟠ Ethereum (ETH) | `0x512936ca43829C8f71017aE47460820Fe703CAea` |
| ◎ Solana (SOL) | `6ZZrRmeGWMZSmBnQFWXG2UJauqbEgZnwb4Ly9vLYr7mi` |

Every bit of support is deeply appreciated! 🙏

---

## 📄 License

This project is open source. See [LICENSE](LICENSE.md) for details.
