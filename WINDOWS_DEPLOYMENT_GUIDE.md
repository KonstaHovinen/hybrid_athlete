# Windows Deployment Guide

## ✅ Compatibility Check

Your Flutter app is **100% compatible** with Windows. All dependencies support Windows:
- ✅ `shared_preferences` (Windows support)
- ✅ `table_calendar` (platform-agnostic)
- ✅ `intl` (platform-agnostic)
- ✅ No Android/iOS-specific code detected

## Prerequisites

1. **Visual Studio 2022** (Community edition is free)
   - Install with "Desktop development with C++" workload
   - Download: https://visualstudio.microsoft.com/downloads/

2. **Flutter SDK** (you already have this)
   - Verify: `flutter doctor -v`
   - Should show Windows support enabled

3. **Enable Windows Desktop** (if not already done)
   ```bash
   flutter config --enable-windows-desktop
   ```

## Build Steps

### 1. Verify Windows Support
```bash
flutter doctor -v
```
Look for:
- ✅ Windows toolchain installed
- ✅ Visual Studio installed
- ✅ Windows desktop enabled

### 2. Get Dependencies
```bash
flutter pub get
```

### 3. Build Windows Release
```bash
flutter build windows --release
```

### 4. Find Your Executable
After build completes, your `.exe` is located at:
```
build\windows\x64\runner\Release\hybrid_athlete.exe
```

## Distribution Options

### Option 1: Simple Distribution (Recommended for Testing)
1. Navigate to: `build\windows\x64\runner\Release\`
2. Zip the entire folder
3. Share the zip file
4. Users extract and run `hybrid_athlete.exe`

**Note**: The entire `Release` folder must be kept together (contains required DLLs)

### Option 2: Windows Installer (For Production)

#### Using Inno Setup (Free, Recommended)
1. Download Inno Setup: https://jrsoftware.org/isdl.php
2. Create installer script that:
   - Copies all files from `Release` folder
   - Creates Start Menu shortcut
   - Creates Desktop shortcut
   - Sets up uninstaller

#### Using NSIS (Free Alternative)
1. Download NSIS: https://nsis.sourceforge.io/Download
2. Create installer script

#### Using Flutter's Built-in Installer (Advanced)
- Requires additional setup with `msix` package
- Creates `.msix` installer (Windows Store format)

## Testing Checklist

Before distributing, test on a clean Windows machine:

- [ ] App launches without errors
- [ ] SharedPreferences saves data correctly
- [ ] Calendar widget displays properly
- [ ] All screens navigate correctly
- [ ] Workout logging works
- [ ] History loads correctly
- [ ] Stats calculate properly
- [ ] No console errors

## Performance Notes

- First launch may be slower (JIT compilation)
- Subsequent launches are faster (AOT compiled)
- Memory usage should be < 200MB
- File paths work correctly (Windows uses backslashes, but Flutter handles this)

## Troubleshooting

### "MSBuild not found"
- Install Visual Studio 2022 with C++ workload
- Restart terminal after installation

### "CMake not found"
- Install CMake: https://cmake.org/download/
- Or install via Visual Studio installer

### "App won't launch"
- Check Windows Defender isn't blocking it
- Ensure all DLLs are in the same folder as `.exe`
- Check Windows Event Viewer for errors

### "Data not saving"
- Check Windows permissions
- Verify SharedPreferences path is writable
- Check for antivirus interference

## Build Configuration

### Debug Build (for development)
```bash
flutter build windows --debug
```
- Larger file size
- Slower performance
- Includes debugging symbols

### Release Build (for distribution)
```bash
flutter build windows --release
```
- Optimized performance
- Smaller file size
- Production-ready

### Profile Build (for performance testing)
```bash
flutter build windows --profile
```
- Optimized but with profiling enabled
- Useful for performance analysis

## File Size Optimization

Your current build should be approximately:
- **Release**: 30-50 MB (with all DLLs)
- **Debug**: 80-120 MB

To reduce size:
1. Remove unused assets
2. Enable tree-shaking (already enabled by default)
3. Use `flutter build windows --release --split-debug-info=<directory>`

## Next Steps

1. ✅ Build Windows release
2. ✅ Test on clean Windows machine
3. ✅ Create installer (optional)
4. ✅ Distribute to users

## Additional Resources

- Flutter Windows Docs: https://docs.flutter.dev/development/platform-integration/desktop
- Windows Desktop Support: https://docs.flutter.dev/development/platform-integration/desktop#windows
- Inno Setup Tutorial: https://jrsoftware.org/ishelp/

---

**Your app is ready for Windows deployment!** 🎉
