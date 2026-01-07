# 🔗 Link Your Netlify Site to GitHub for Auto-Updates

## Current Situation
✅ App is deployed and working on iPhone  
⚠️ But it's not linked to your GitHub repo (was drag & drop)

## 🎯 Solution: Link to GitHub for Auto-Deployment

### Step 1: Find Your Site on Netlify

1. Go to https://app.netlify.com/
2. You'll see your deployed site
3. Click on it

### Step 2: Link to GitHub

1. Go to **Site settings** (in top menu)
2. Click **"Build & deploy"** in sidebar
3. Scroll to **"Build settings"**
4. Click **"Link repository"** or **"Link site to Git"**
5. Choose **GitHub**
6. Select repository: **`hybrid_athlete`**
7. Branch: **`main`**
8. Build settings:
   - Base directory: (leave empty)
   - Build command: (leave empty - we use pre-built files)
   - Publish directory: `build/web`

9. Click **"Save"**

### Step 3: Done! ✅

Now whenever you push to GitHub, Netlify auto-deploys!

---

## 🔄 Future Update Workflow

### When You Make Changes:

```bash
# 1. Make your code changes in lib/

# 2. Test locally
flutter run -d chrome

# 3. Rebuild web version
flutter build web --release

# 4. Commit and push
git add .
git commit -m "Update: added new feature"
git push

# 5. Netlify auto-deploys! 🚀
# Your iPhone app updates automatically next time you open it
```

---

## 📱 How iPhone Gets Updates

### Automatic Updates:
- PWA checks for updates when you open it
- Downloads new version in background
- Applies on next app restart
- **User doesn't need to do anything!**

### Force Update (if needed):
1. Open Safari (not the app icon)
2. Go to your Netlify URL
3. Hard refresh: Pull down to refresh
4. Add to Home Screen again (replaces old version)

---

## 🎯 Alternative: Keep Drag & Drop Method

If you prefer manual control:

### When You Update:
```bash
# 1. Make changes
# 2. Rebuild web
flutter build web --release

# 3. Deploy to Netlify
#    Option A: Drag & drop (https://app.netlify.com/drop)
#    Option B: CLI
netlify deploy --prod --dir=build/web
```

**Pros:**
- ✅ Full control over when to deploy
- ✅ Test before making live
- ✅ No auto-deploy surprises

**Cons:**
- ⚠️ Manual step each time
- ⚠️ Can forget to deploy

---

## 💡 Recommended Setup

**Best of both worlds:**

1. **Link to GitHub** for automatic deploys
2. **Use branch protection**:
   - Create `dev` branch for testing
   - Only merge to `main` when ready
   - Only `main` auto-deploys to Netlify

This way:
- ✅ Auto-deploy when ready
- ✅ Control over what goes live
- ✅ No manual drag & drop

---

## 🚀 Summary

### Current Status:
- ✅ App working on iPhone
- ✅ Web build in GitHub repo
- ⚠️ Not auto-linked yet

### To Enable Auto-Deploy:
1. Netlify dashboard → Your site
2. Site settings → Build & deploy
3. Link repository → GitHub → hybrid_athlete
4. Publish directory: `build/web`
5. Save

### Future Updates:
```bash
flutter build web --release
git add . && git commit -m "Update" && git push
# Netlify auto-deploys! ✅
```

**Choose what works best for you!** 🎉
