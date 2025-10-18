# PowerTime ⚡

Schedule heavy loads for optimal dynamic tariff.

A Flutter app that helps you schedule high-power appliances (washing machines, EVs, water heaters, etc.) to run during off-peak electricity pricing periods, saving you money on your energy bills.

**[🌐 Live Demo](https://walking-octopus.github.io/load_schedule/)** • **[📱 Download APK](https://github.com/walking-octopus/load_schedule/actions)** (Actions → Latest run → Artifacts)

## Features

- 📊 Live energy price forecast visualization
- 🔌 12+ preset appliances (or add custom loads)
- ⏰ Smart scheduling with optimal time windows
- 💰 Savings estimates for each scheduled load
- 🔁 Recurring load scheduling
- 🎯 Beautiful Material Design 3 UI
- 🔧 An accurate control-theory model of tariff prices

> **Note:** Built as a hackathon project featuring a sophisticated control theory-based tariff pricing model with multiple harmonics for realistic daily patterns, underdamped step response for demand peaks, Ornstein-Uhlenbeck process for stochastic price variations, and 15-minute tariff intervals aligned to real-world pricing.

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on your preferred platform
flutter run

# Or build for release
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
flutter build linux      # Linux
flutter build windows    # Windows
flutter build macos      # macOS
```

## TODO

Next steps: Integrate real Nord Pool API data (currently using mock control theory model)
