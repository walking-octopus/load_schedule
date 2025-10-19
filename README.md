# PowerTime ⚡

Schedule heavy loads for optimal dynamic tariff, desegregate your bills into probable load categories, get tips to reduce your consumption, log past bills and predict future ones.

**[🌐 Live Demo](https://walking-octopus.github.io/load_schedule/)** • **[📱 Download APK](https://github.com/walking-octopus/load_schedule/actions)** (Actions → Latest run → Artifacts)

## Features

- 📊 Live energy price forecast visualization
- ⏰ Smart scheduling with optimal time windows for recurring and deferred loads
- 💰 Savings estimates for each scheduled load
- 🔧 An accurate control-theory model of tariff prices
- ❓ A sound probabalistic-programming model of household power consumption
- 👥 National consumption percentile for your household
- 👌 Personalized appliance upgrade recomendations to reduce your bill
- 🎯 Beautiful Material Design 3 UI
- 📱 Avalible on Android, ~~iOS~~, and web

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

Next steps: Integrate real Nord Pool API data (currently using theoretical control theory model)
