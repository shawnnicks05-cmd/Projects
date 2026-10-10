# App Icon Setup Instructions

## Steps to Change App Icon:

### 1. Update pubspec.yaml
Add the following to your `pubspec.yaml` file:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  image_path: "assets/icon/bot_icon.png"
  image_path_ios: "assets/icon/bot_icon.png"
  windows:
    generate: true
    image_path: "assets/icon/bot_icon.png"
  android:
    generate: true
  ios:
    generate: true
```

### 2. Create Icon Image
Place a PNG icon image (at least 1024x1024 pixels) in:
```
frontend/assets/icon/bot_icon.png
```

You can:
- Use an online bot icon (search for "bot icon PNG")
- Create one in a design tool (Figma, Canva, etc.)
- Use a simple design with a black bot on transparent background

### 3. Generate Icons
Run these commands in the frontend directory:

```powershell
cd C:\Users\shawn\Desktop\A.I MODEL\frontend

# Install the package
flutter pub get

# Generate launcher icons
dart run flutter_launcher_icons

# Clean and rebuild
flutter clean
flutter pub get
flutter run -d windows
```

### 4. Icon Requirements
- **Size**: 1024x1024 pixels minimum
- **Format**: PNG with transparency
- **Colors**: Works best with your dark theme (black/dark icon on transparent background)
- **File**: Save as `bot_icon.png` in `assets/icon/` folder

### Recommended Icon Design
- Dark bot silhouette
- Transparent background
- Simple, scalable design
- Similar to your in-app bot icon

Once you have the icon image, run the commands above and the app icon will automatically update for Windows, Android, and iOS!
