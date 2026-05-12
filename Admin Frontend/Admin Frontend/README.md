# TGTS Admin Frontend

Admin dashboard for the Telangana Congress Communication App (TGTS).

## Features

- User Management
- Event Management
- Media Management (Photos & Videos)
- Document Upload and Management
- Content Push Notifications
- Dashboard with Analytics

## Tech Stack

- React 19
- TypeScript
- Vite
- Tailwind CSS
- Axios
- React Router

## Development

### Prerequisites

- Node.js 18+ 
- npm or yarn

### Setup

1. Clone the repository:
```bash
git clone https://github.com/Satya-Sreekar/TGTS_Admin.git
cd TGTS_Admin
```

2. Install dependencies:
```bash
npm install
```

3. Configure API endpoint (optional, defaults to localhost for development):
   
   Create a `.env.local` file for local development:
   ```bash
   # Set to true to use production API, false for local development
   VITE_USE_PRODUCTION=false
   
   # Local API URL (default: http://localhost:5000/api)
   # Change this if your Flask backend runs on a different port
   VITE_API_URL=http://localhost:5000/api
   ```
   
   **Note:** By default, the app uses `http://localhost:5000/api` for local development.
   To use production API, set `VITE_USE_PRODUCTION=true` in your `.env.local` file.

4. Start the development server:
```bash
npm run dev
```

The app will be available at `http://localhost:5173`

## Building for Production

```bash
npm run build
```

The built files will be in the `dist` directory.

## AWS Amplify Deployment

### Prerequisites

1. AWS Account
2. GitHub repository connected (already done: `TGTS_Admin`)
3. Backend API running at `https://apitgts.codeology.solutions`

### Deployment Steps

1. **Log into AWS Amplify Console**
   - Go to [AWS Amplify Console](https://console.aws.amazon.com/amplify)
   - Click "New app" > "Host web app"

2. **Connect Repository**
   - Select "GitHub" as your source
   - Authorize AWS Amplify to access your GitHub account
   - Select the `TGTS_Admin` repository
   - Select the `main` branch

3. **Configure Build Settings**
   - The build is automatically detected from `amplify.yml`
   - Verify the build settings:
     - Build command: `npm run build`
     - Output directory: `dist`

4. **Set Environment Variables**
   - In the Amplify Console, go to your app settings
   - Navigate to "Environment variables"
   - Add the following variable to use production API:
     ```
     Key: VITE_USE_PRODUCTION
     Value: true
     ```
   - Optionally, you can also set a custom API URL:
     ```
     Key: VITE_API_URL
     Value: https://apitgts.codeology.solutions/api
     ```
   - **Note:** The production backend URL (`https://apitgts.codeology.solutions/api`) is hardcoded and will be used when `VITE_USE_PRODUCTION=true`

5. **Configure Custom Headers (for CORS)**
   - In Amplify Console, go to "Rewrites and redirects"
   - The app should already be configured to handle SPA routing
   - Ensure your backend at `apitgts.codeology.solutions` allows CORS from your Amplify domain

6. **Deploy**
   - Click "Save and deploy"
   - Amplify will build and deploy your app
   - You'll get a URL like: `https://main.xxxxx.amplifyapp.com`

### Custom Domain (Optional)

1. In Amplify Console, go to your app
2. Click on "Domain management"
3. Add your custom domain
4. Follow the DNS configuration instructions

## Environment Variables

The app uses the following environment variables:

- `VITE_API_URL`: Backend API URL (default: `https://apitgts.codeology.solutions/api`)

### Setting Environment Variables

#### Local Development
Create a `.env.local` file:
```
VITE_API_URL=http://localhost:80/api
```

#### AWS Amplify
Set environment variables in the Amplify Console under App Settings > Environment variables.

## API Configuration

The app is configured to connect to the backend API at:
- **Production**: `https://apitgts.codeology.solutions/api`
- **Development**: `http://localhost:80/api` (if configured)

## Backend CORS Configuration

Ensure your backend allows CORS requests from your Amplify domain. Add your Amplify app URL to the allowed origins in your backend CORS configuration.

## Project Structure

```
Admin Frontend/
├── src/
│   ├── components/       # Reusable components
│   ├── contexts/         # React contexts
│   ├── features/         # Feature modules
│   ├── layout/           # Layout components
│   ├── pages/             # Page components
│   ├── services/          # API services
│   └── utils/             # Utility functions
├── public/                # Static assets
├── amplify.yml           # AWS Amplify build configuration
└── vite.config.ts        # Vite configuration
```

## Troubleshooting

### Build Fails in Amplify

1. Check build logs in Amplify Console
2. Ensure Node.js version is 18+ (configure in amplify.yml if needed)
3. Verify all dependencies are in package.json

### API Connection Issues

1. Verify backend is running at `https://apitgts.codeology.solutions`
2. Check browser console for CORS errors
3. Ensure backend allows requests from your Amplify domain

### Routing Issues (404 on page refresh)

- Amplify redirects are configured automatically via `amplify.yml`
- If issues persist, check "Rewrites and redirects" in Amplify Console

## License

[Your License Here]

