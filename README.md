# ⚡ PowerTime

Schedule heavy loads for optimal dynamic tariff, desegregate your bills into probable load categories, get tips to reduce your consumption, log past bills and predict future ones.

> A 2025 HackForVilnius project

[🌐 Web Demo](https://walking-octopus.github.io/load_schedule/) | [📱 Download APK]([https://github.com/walking-octopus/load_schedule/actions](https://nightly.link/walking-octopus/load_schedule/workflows/build-and-deploy/main/powertime-android.zip))

<div align="center">
  <img src="https://github.com/user-attachments/assets/dbf5c9d5-3d16-4bbe-ab7a-5e9631d6ad83" alt="Schedule loads" width="200"/>
  <img src="https://github.com/user-attachments/assets/002df84b-6e26-4eec-8138-d60348f0e293" alt="Analyze bills" width="200"/>
  <img src="https://github.com/user-attachments/assets/d091b11a-62f7-48ff-aa8e-a8df57444ea6" alt="Predict the future" width="200"/>
  <img src="https://github.com/user-attachments/assets/5a5d6bba-66fd-46d9-abd9-e752086924d0" alt="Compare to others; Get efficiency tips" width="200"/>
</div>

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

## Futher work

- [ ] Integrate Nord Pool API data (currently using theoretical model)
- [ ] Distribution conditioning on historical bills
