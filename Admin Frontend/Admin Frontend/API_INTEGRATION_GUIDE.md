# Frontend-Backend Integration Guide

## ✅ Integration Complete!

Your Political Web application is now fully connected with the TGTS Backend API.

## 🚀 Running the Application

### Frontend (React + Vite)
**Status:** ✅ Running
- **URL:** http://localhost:5174/
- **Command:** `npm run dev`

### Backend (Flask API)
**Status:** ✅ Running
- **URL:** http://localhost:5001/api (Port 5001 because Windows blocks port 5000)
- **API Docs:** http://localhost:5001/docs/
- **Health Check:** http://localhost:5001/api/health
- **Command:** `cd TGTS_Backend && $env:PORT="5001" && python app.py`

## 📁 What Was Created

### 1. API Services Layer (`src/services/`)
- **`api.ts`**: Base Axios instance with authentication interceptors
- **`authService.ts`**: Authentication (OTP login, verify, profile)
- **`userService.ts`**: User management operations
- **`eventService.ts`**: Event management and RSVP
- **`documentService.ts`**: Document upload and management
- **`adminService.ts`**: Dashboard stats and admin operations

### 2. Authentication Context (`src/contexts/`)
- **`AuthContext.tsx`**: Global authentication state management
- Provides user info, login/logout, and authentication status
- Automatically validates tokens on app load

### 3. Environment Configuration
- **API URL**: Defaults to `http://localhost:5001/api` (configured in `src/services/api.ts`)
- Can be overridden with `VITE_API_URL` environment variable
- **Note**: Port 5001 is used because Windows often blocks port 5000

## 🔧 Updated Components

### Dashboard (`src/features/dashboard/Dashboard.tsx`)
- ✅ Fetches real-time statistics from `/api/admin/dashboard`
- ✅ Displays total users, active users, published news, upcoming events
- ✅ Shows recent activity from the backend
- ✅ Falls back to sample data if API is unavailable

### User Management (`src/features/users/UserManagement.tsx`)
- ✅ Fetches users from `/api/users/`
- ✅ Supports pagination, filtering by role, and search
- ✅ Loading states and error handling
- ✅ Falls back to sample data if API is unavailable

### Main App (`src/main.tsx`)
- ✅ Wrapped with `AuthProvider` for global authentication
- All components can now use `useAuth()` hook

## 🔐 Authentication Flow

1. **Login:**
   ```typescript
   // Send OTP
   await authService.sendOTP({ phone: "9876543210" });
   
   // Verify OTP
   await authService.verifyOTP({ phone: "9876543210", otp: "123456" });
   ```

2. **Using Auth in Components:**
   ```typescript
   import { useAuth } from '../contexts/AuthContext';
   
   function MyComponent() {
     const { user, isAuthenticated, logout } = useAuth();
     // ...
   }
   ```

3. **Protected API Calls:**
   - All API calls automatically include JWT token from localStorage
   - Token is added via Axios interceptor
   - Unauthorized requests (401) automatically redirect to login

## 📡 Available API Endpoints

### Authentication
- `POST /api/auth/login` - Send OTP
- `POST /api/auth/verify-otp` - Verify OTP and login
- `GET /api/auth/profile` - Get current user profile
- `PUT /api/auth/profile` - Update profile

### Users
- `GET /api/users/` - Get all users (with pagination, filters)
- `GET /api/users/:id` - Get user by ID
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

### Events
- `GET /api/events/` - Get all events
- `GET /api/events/:id` - Get event by ID
- `POST /api/events/` - Create event (admin)
- `PUT /api/events/:id` - Update event (admin)
- `DELETE /api/events/:id` - Delete event (admin)
- `POST /api/events/:id/rsvp` - RSVP to event

### Documents
- `GET /api/documents/` - Get all documents
- `GET /api/documents/:id` - Get document by ID
- `POST /api/documents/` - Create document (admin)
- `PUT /api/documents/:id` - Update document (admin)
- `DELETE /api/documents/:id` - Delete document (admin)
- `POST /api/documents/upload` - Upload file

### Admin
- `GET /api/admin/dashboard` - Get dashboard statistics
- `GET /api/admin/analytics` - Get analytics data
- `POST /api/admin/content-push` - Push content to users
- `GET /api/admin/system-health` - Get system health status

## 🔄 How to Use API Services in Other Components

### Example: Fetch Events
```typescript
import { eventService } from '../../services/eventService';

function EventList() {
  const [events, setEvents] = useState([]);
  
  useEffect(() => {
    async function fetchEvents() {
      const response = await eventService.getEvents({ 
        upcoming_only: true,
        per_page: 10 
      });
      setEvents(response.data);
    }
    fetchEvents();
  }, []);
}
```

### Example: Create Event (Admin)
```typescript
import { eventService } from '../../services/eventService';

async function handleCreateEvent(data) {
  try {
    const newEvent = await eventService.createEvent({
      title_en: "Rally",
      description_en: "Political rally",
      event_date: "2024-12-01",
      location_en: "Hyderabad",
      is_published: true
    });
    console.log('Event created:', newEvent);
  } catch (error) {
    console.error('Failed to create event:', error);
  }
}
```

## 🐛 Troubleshooting

### CORS Errors
The backend is configured to allow CORS from `http://localhost:3000` and `http://localhost:5173`. If you see CORS errors, check the backend configuration in `TGTS_Backend/app/config.py`.

### Connection Refused
Make sure both servers are running:
- Frontend: `npm run dev`
- Backend: `cd TGTS_Backend && python app.py`

### 401 Unauthorized
The API requires authentication for most endpoints. Make sure you're logged in or the endpoint requires admin privileges.

### API Not Found (404)
Check that:
1. Backend is running on port 5000
2. The API endpoint exists in the backend
3. You're using the correct HTTP method (GET, POST, PUT, DELETE)

## 📦 Dependencies Added
- `axios` - HTTP client for API requests

## 🎯 Next Steps

1. **Implement Login Page**: Create a login component using `authService.sendOTP()` and `authService.verifyOTP()`

2. **Add Protected Routes**: Use `useAuth()` to protect routes that require authentication

3. **Update Remaining Components**: Connect EventManagement, ContentPush, and UploadDocuments to their respective API services

4. **Error Handling**: Add toast notifications or error messages for API failures

5. **Loading States**: Add skeleton screens for better UX during data fetching

## 🔒 Security Notes

- JWT tokens are stored in localStorage
- Tokens expire after 24 hours
- All admin endpoints require admin role
- OTP verification is required for login
- HTTPS should be used in production

## 📚 Additional Resources

- Flask API Documentation: http://localhost:5000/docs/
- Backend README: `TGTS_Backend/README.md`
- Backend Configuration: `TGTS_Backend/app/config.py`

---

**Integration completed successfully!** 🎉

Your frontend is now communicating with the backend API. Check the browser console for any errors, and use the browser's Network tab to inspect API requests.

