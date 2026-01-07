# 📱 Deploy to iPhone (PWA)

## Quick Deploy to Netlify (5 minutes)

### 1. Push to GitHub
```bash
git add .
git commit -m "Add web build and deployment config"
git push
```

### 2. Deploy to Netlify
1. Go to: https://app.netlify.com/
2. Sign up with GitHub (free)
3. Click "Add new site" → "Import an existing project"
4. Select your GitHub repo: `hybrid_athlete`
5. Deploy settings (auto-detected from netlify.toml):
   - Build command: `flutter build web --release`
   - Publish directory: `build/web`
6. Click "Deploy site"

**Your app will be live at**: `https://[random-name].netlify.app`

### 3. Add to iPhone Home Screen
1. Open Safari on iPhone
2. Go to your Netlify URL
3. Tap Share button (square with arrow)
4. Tap "Add to Home Screen"
5. Name it "Hybrid Athlete"
6. Tap "Add"

**Done!** App icon on your iPhone, works offline! 🎉

---

## Alternative: Self-Host (If you have a server)

```bash
# Just copy build/web folder to any web server
# Example: Apache, Nginx, or even Python HTTP server
cd build/web
python -m http.server 8000
```

Then access from iPhone on same WiFi: `http://[your-pc-ip]:8000`

---

## Why PWA is Perfect for Tomorrow:
- ✅ Works offline (logs workouts without internet)
- ✅ Saves to local storage (your data stays on phone)
- ✅ Feels like native app
- ✅ No Mac needed
- ✅ Free hosting
- ✅ Updates instantly (just rebuild and push)

**Ready in ~10 minutes!**
