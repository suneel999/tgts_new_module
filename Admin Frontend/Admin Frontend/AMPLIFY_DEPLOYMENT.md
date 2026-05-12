# AWS Amplify Deployment Guide

This guide walks you through deploying the TGTS Admin Frontend to AWS Amplify.

## Prerequisites

- AWS Account with Amplify access
- GitHub repository already set up (✅ Done: `TGTS_Admin`)
- Backend API running at `https://apitgts.codeology.solutions`

## Quick Start

### 1. Create New Amplify App

1. Go to [AWS Amplify Console](https://console.aws.amazon.com/amplify)
2. Click **"New app"** > **"Host web app"**
3. Select **GitHub** as your source provider
4. Authorize AWS Amplify to access your GitHub account if prompted

### 2. Connect Repository

1. Select the repository: **`TGTS_Admin`**
2. Select the branch: **`main`**
3. Click **"Next"**

### 3. Configure Build Settings

Amplify should auto-detect the build settings from `amplify.yml`. Verify:

- **App name**: TGTS_Admin (or your preferred name)
- **Build specification**: `amplify.yml`
- Build commands are automatically detected:
  - Pre-build: `npm ci`
  - Build: `npm run build`
  - Output directory: `dist`

Click **"Next"**

### 4. Review and Deploy

1. Review the configuration
2. Click **"Save and deploy"**
3. Wait for the build to complete (usually 3-5 minutes)

### 5. Access Your App

Once deployment completes, you'll get a URL like:
```
https://main.xxxxx.amplifyapp.com
```

## Environment Variables

The app is configured with production API URL by default. If you need to override:

1. In Amplify Console, go to your app
2. Navigate to **"App settings"** > **"Environment variables"**
3. Add variable (optional):
   ```
   Key: VITE_API_URL
   Value: https://apitgts.codeology.solutions/api
   ```
4. Redeploy the app

## Custom Domain Setup (Optional)

### Option 1: Add Domain in Amplify

1. In Amplify Console, select your app
2. Click **"Domain management"** in the left sidebar
3. Click **"Add domain"**
4. Enter your domain name
5. Follow the DNS configuration instructions
6. Wait for SSL certificate provisioning (usually 30-60 minutes)

### Option 2: Configure Existing Domain

If you already have a domain:

1. Add a CNAME record in your DNS provider:
   - **Name**: `admin` (or your subdomain)
   - **Value**: Your Amplify app URL (e.g., `main.xxxxx.amplifyapp.com`)
2. In Amplify, add your domain following Option 1 steps

## Backend CORS Configuration

**IMPORTANT**: Ensure your backend allows CORS from your Amplify domain.

Add your Amplify app URL to the allowed origins in your backend:

Example Flask backend CORS configuration:
```python
from flask_cors import CORS

CORS(app, resources={
    r"/api/*": {
        "origins": [
            "https://main.xxxxx.amplifyapp.com",
            "https://yourcustomdomain.com"
        ],
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})
```

## Continuous Deployment

Amplify automatically redeploys when you push to the `main` branch:

1. Make changes locally
2. Commit and push:
   ```bash
   git add .
   git commit -m "Your changes"
   git push origin main
   ```
3. Amplify will automatically build and deploy

## Build Monitoring

- View build logs in the Amplify Console under "Hosting" > "Build history"
- Build notifications can be configured in App settings > Notifications

## Troubleshooting

### Build Fails

1. **Check build logs** in Amplify Console
2. **Common issues**:
   - Node.js version mismatch → Add to `amplify.yml`:
     ```yaml
     preBuild:
       commands:
         - nvm use 18
         - npm ci
     ```
   - Missing dependencies → Ensure all deps are in `package.json`
   - Build errors → Check TypeScript errors locally first

### API Connection Errors

1. **Check CORS**: Ensure backend allows your Amplify domain
2. **Verify API URL**: Check browser console for the API URL being used
3. **Check Network tab**: Look for failed requests and CORS errors
4. **Environment variables**: Verify `VITE_API_URL` is set correctly

### 404 on Page Refresh

This shouldn't happen with the `_redirects` file in `public/`, but if it does:

1. In Amplify Console, go to **"Rewrites and redirects"**
2. Add rule:
   - **Source address**: `</^[^.]+$|\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json)$)([^.]+$)/>`
   - **Target address**: `/index.html`
   - **Type**: `200 (Rewrite)`

### Routing Not Working

- Verify `_redirects` file exists in `public/` directory
- Check Amplify "Rewrites and redirects" settings
- Clear browser cache

## Performance Optimization

The app is configured for production builds:
- Source maps disabled
- Optimized bundle size
- Asset caching enabled

## Security Headers

Security headers are configured in `amplify.yml`:
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block
- Referrer-Policy: strict-origin-when-cross-origin

## Next Steps

After deployment:
1. ✅ Test authentication flow
2. ✅ Verify API connections
3. ✅ Test all features (dashboard, media upload, events, etc.)
4. ✅ Set up custom domain (if needed)
5. ✅ Configure monitoring and alerts

## Support

For issues:
1. Check Amplify build logs
2. Check browser console for errors
3. Verify backend is accessible
4. Review this guide and README.md

