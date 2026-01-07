# Hybrid Athlete Sync Guide

## 🔄 What is the Sync System?

The sync system exports your workout data to a **local JSON file** whenever you save anything on your phone. The desktop command center reads this file to display your data.

**Current Implementation:**
- **Phone**: Exports data to `Documents/HybridAthlete/hybrid_athlete_sync.json` on save
- **Desktop**: Watches this file and auto-refreshes when it changes
- **Format**: Plain JSON file (human-readable, no encryption)

---

## 📱 How to Connect Phone + Desktop

### Option 1: Cloud Storage Sync (Recommended) ⭐

**Best for: Automatic, seamless sync**

1. **Set up cloud storage on both devices:**
   - **Windows Desktop**: Install OneDrive, Google Drive, or Dropbox
   - **Android Phone**: Install the same cloud app

2. **Point sync folder to cloud:**
   - The sync file is in `Documents/HybridAthlete/`
   - Move this folder to your cloud storage folder (e.g., `OneDrive/HybridAthlete/`)
   - Update the sync path in code (or we can make it configurable)

3. **Result**: 
   - Phone saves → Uploads to cloud → Desktop downloads → Auto-refreshes
   - Works automatically in background

### Option 2: Manual File Transfer

**Best for: One-time or occasional sync**

1. **On Phone**: After logging workouts, copy `hybrid_athlete_sync.json` from app documents
2. **Transfer to Desktop**: USB, email, or cloud upload
3. **Place on Desktop**: Put in `Documents/HybridAthlete/` folder
4. **Desktop**: Opens file and displays data

### Option 3: Network Sync (Future Enhancement)

**Best for: Real-time sync without cloud**

- Phone and desktop on same WiFi
- Phone runs a simple HTTP server
- Desktop connects and pulls data
- More complex but fully local

---

## 🔒 Is It Safe?

### ✅ **YES - Current Implementation is Safe:**

1. **Local Files Only**: 
   - No external servers
   - No internet connection required
   - Data never leaves your devices (unless you use cloud storage)

2. **No Authentication Needed**:
   - It's your personal app
   - No login/accounts
   - No data sharing

3. **Plain JSON**:
   - Human-readable
   - Easy to backup
   - Easy to inspect/debug

### ⚠️ **Security Considerations:**

1. **If using Cloud Storage**:
   - Your data will be in the cloud (OneDrive/Google Drive)
   - Protected by your cloud account security
   - Consider if you want workout data in cloud

2. **File Permissions**:
   - Currently readable by anyone with file access
   - Could add encryption if needed (future enhancement)

3. **Network Sync (if we add it)**:
   - Would only work on local network
   - No external exposure

---

## 🛠️ Current Sync File Location

**Windows Desktop:**
```
C:\Users\[YourName]\Documents\HybridAthlete\hybrid_athlete_sync.json
```

**Android Phone:**
```
/data/data/com.example.hybrid_athlete/app_flutter/HybridAthlete/hybrid_athlete_sync.json
```
(Internal app storage - not easily accessible without root)

**macOS/Linux:**
```
~/Documents/HybridAthlete/hybrid_athlete_sync.json
```

---

## 💡 Recommended Setup

For **automatic sync between phone and desktop**:

1. **Use OneDrive/Google Drive**:
   - Create `HybridAthlete` folder in cloud storage
   - Update sync service to use cloud folder path
   - Both devices sync automatically

2. **Or use a shared network folder**:
   - If phone and desktop on same network
   - Use network share (SMB) folder
   - Both devices point to same network location

---

## 🔧 Making Sync Path Configurable

Would you like me to:
1. Add a settings screen to choose sync location?
2. Add cloud storage folder detection?
3. Add encryption for sensitive data?
4. Add network sync option?

Let me know your preference!

---

## 📊 What Gets Synced?

- ✅ Workout history (all logged workouts)
- ✅ Templates (your custom workout templates)
- ✅ User exercises (custom exercises you added)
- ✅ Profile data (name, PRs, stats)
- ✅ Exercise settings (custom rep ranges, weights)
- ✅ Goals (pro goals, weekly goals)
- ✅ Calendar data (scheduled/logged workouts)

**Everything except active workout tracking** (which is phone-only).
