# Troubleshooting Blank Screen

## Quick Diagnostic Steps

### 1. Open Browser Console (F12)
Look for these messages in order:
```
🚀 Starting Political Web App...
✅ Root element found, creating React app...
API Base URL: http://localhost:5001/api
App component rendering
AppLayout rendering
```

### 2. Check for Errors
Look in the Console tab for:
- ❌ Red error messages
- ⚠️ Yellow warnings
- Any failed network requests

### 3. Check Network Tab
- Open Network tab in DevTools
- Refresh the page (Ctrl+Shift+R or Cmd+Shift+R)
- Look for failed requests (red)
- Check if main.tsx loads successfully

### 4. Common Issues and Fixes

#### Issue: Console shows errors about modules not found
**Solution:** 
```bash
npm install
```
Then restart the dev server.

#### Issue: "Cannot read property of undefined"
**Solution:** Check which component is throwing the error and simplify it.

#### Issue: Stuck on "Loading..."
**Solution:** This was fixed - AuthContext no longer blocks rendering.

#### Issue: White/blank screen, no console errors
**Possible causes:**
1. CSS not loading - check if index.css is loaded in Network tab
2. React not rendering - check if main.tsx is loaded
3. HTML issue - view page source to verify root div exists

**Solution:**
```bash
# Clear browser cache and restart
Ctrl+Shift+R (or Cmd+Shift+R on Mac)

# Or hard refresh Vite
npm run dev -- --force
```

#### Issue: Console shows "Failed to fetch" or CORS errors
**Solution:**
- Backend must be running on port 5001
- Check: `http://localhost:5001/api/health`
- Restart backend: `cd TGTS_Backend && $env:PORT="5001" && python app.py`

### 5. Nuclear Option - Full Reset

If nothing works:

```bash
# Stop all servers (Ctrl+C)

# Clear all caches
Remove-Item -Path node_modules -Recurse -Force
Remove-Item -Path package-lock.json
npm install

# Restart frontend
npm run dev
```

```bash
# In another terminal, restart backend
cd TGTS_Backend
$env:FLASK_DEBUG="True"
$env:PORT="5001"
python app.py
```

### 6. Verify Servers Are Running

**Frontend Check:**
- Should see: `VITE v7.1.10 ready in XXX ms`
- URL: `http://localhost:5174/` (or 5173)

**Backend Check:**
```powershell
Invoke-WebRequest -Uri "http://localhost:5001/api/health" -UseBasicParsing
```
Should return:
```json
{
  "status": "healthy",
  "timestamp": "...",
  "version": "1.0.0"
}
```

### 7. What You Should See

When working correctly, the browser should show:
1. Sidebar on the left with navigation menu
2. Dashboard with statistics cards
3. Charts and recent activity
4. Orange/green color scheme

### 8. If Screen is Still Blank

Try this test component to isolate the issue:

Create `src/TestApp.tsx`:
```typescript
export default function TestApp() {
  return (
    <div style={{ padding: '20px', fontSize: '24px' }}>
      <h1>🎉 React is Working!</h1>
      <p>If you see this, React is rendering correctly.</p>
      <p>The issue is in one of your components.</p>
    </div>
  );
}
```

Update `src/main.tsx`:
```typescript
import TestApp from "./TestApp";
// Comment out the normal App import

// In createRoot().render(), replace <App /> with <TestApp />
```

If TestApp shows up:
- React is working fine
- Issue is in App.tsx, AppLayout, or child components
- Uncomment components one by one to find the culprit

If TestApp doesn't show:
- Issue is with React setup or build
- Run `npm install` again
- Check for conflicting React versions

### 9. Developer Tools Diagnostic

**Console:**
```javascript
// Type in browser console:
document.getElementById('root')
// Should show: <div id="root">...</div> with content

document.getElementById('root').children.length
// Should be > 0

// Check if React is loaded:
window.React
// Should show React object (in dev mode)
```

**Application Tab:**
- Check LocalStorage for any stored auth tokens
- Clear if needed: `localStorage.clear()`

### 10. Last Resort

If absolutely nothing works:

1. Take a screenshot of:
   - Browser console (all messages)
   - Network tab
   - Any error messages

2. Check:
   - Which browser? (Try Chrome if using something else)
   - Browser extensions? (Try incognito mode)
   - Antivirus/Firewall blocking localhost?

3. Try the app in a different browser

---

## Current Known Working State

✅ Backend running on port 5001
✅ Frontend running on port 5174
✅ No blocking loading screens
✅ Error boundary to catch errors
✅ Debug logging added

The app SHOULD work. If it doesn't, follow steps above!


