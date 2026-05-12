# Telangana Congress Communication App - Flask Backend

A Flask-based REST API backend for the Telangana Congress Communication App, providing authentication, content management, and admin functionality.

## Features

### Authentication & User Management
- **OTP-based Login**: Phone number authentication with OTP verification
- **User Registration**: Automatic user creation on first login
- **Role-based Access**: Public, Cadre, and Admin user roles
- **JWT Authentication**: Secure token-based authentication
- **User Profile Management**: Update user information and preferences

### Content Management
- **News Management**: Create, update, and publish news articles
- **Event Management**: Manage events with RSVP functionality
- **Media Management**: Handle photos and videos with thumbnails
- **Document Management**: Upload and manage documents with access control

### Admin Features
- **Dashboard Analytics**: User statistics and content metrics
- **User Management**: Admin interface for user administration
- **Content Push**: Send notifications to specific user groups
- **System Health**: Monitor system status and performance

### API Features
- **RESTful API**: Clean and consistent API endpoints
- **Pagination**: Efficient data pagination for large datasets
- **Filtering & Search**: Advanced filtering and search capabilities
- **CORS Support**: Cross-origin resource sharing enabled
- **Error Handling**: Comprehensive error handling and validation

## Project Structure

```
flask_backend/
├── app.py                  # Main Flask application
├── requirements.txt        # Python dependencies
├── env_example.txt         # Environment variables template
├── app/
│   ├── models/
│   │   └── __init__.py    # Database models
│   ├── routes/
│   │   ├── auth.py        # Authentication endpoints
│   │   ├── users.py       # User management endpoints
│   │   ├── news.py        # News management endpoints
│   │   ├── events.py      # Event management endpoints
│   │   ├── media.py       # Media management endpoints
│   │   ├── documents.py   # Document management endpoints
│   │   └── admin.py       # Admin endpoints
│   ├── services/          # Business logic services
│   └── utils/             # Utility functions
├── static/
│   ├── uploads/           # File upload directory
│   └── images/            # Image storage
└── migrations/             # Database migrations
```

## Getting Started

### Prerequisites
- Python 3.8 or higher
- pip (Python package installer)
- SQLite (for development) or PostgreSQL (for production)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Satya-Sreekar/TGTS_Backend
   cd flask_backend
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables**
   ```bash
   cp env_example.txt .env
   # Edit .env with your configuration
   ```

5. **Initialize database**
   ```bash
   flask db init
   flask db migrate -m "Initial migration"
   flask db upgrade
   ```

6. **Run the application**
   ```bash
   python app.py
   ```

The API will be available at `http://localhost:5000`

## API Documentation

### Authentication Endpoints

#### POST `/api/auth/login`
Send OTP to phone number
```json
{
  "phone": "9876543210"
}
```

#### POST `/api/auth/verify-otp`
Verify OTP and get access token
```json
{
  "phone": "9876543210",
  "otp": "123456"
}
```

#### GET `/api/auth/profile`
Get current user profile (requires authentication)

#### PUT `/api/auth/profile`
Update user profile (requires authentication)

### User Management Endpoints

#### GET `/api/users/`
Get all users (admin only)
- Query parameters: `page`, `per_page`, `role`, `search`

#### GET `/api/users/<user_id>`
Get specific user details

#### PUT `/api/users/<user_id>`
Update user details (admin only)

#### DELETE `/api/users/<user_id>`
Delete user (admin only)

### News Endpoints

#### GET `/api/news/`
Get published news items
- Query parameters: `page`, `per_page`, `category`

#### GET `/api/news/<news_id>`
Get specific news item

#### POST `/api/news/`
Create news item (admin only)

#### PUT `/api/news/<news_id>`
Update news item (admin only)

#### DELETE `/api/news/<news_id>`
Delete news item (admin only)

### Event Endpoints

#### GET `/api/events/`
Get published events
- Query parameters: `page`, `per_page`, `upcoming_only`

#### GET `/api/events/<event_id>`
Get specific event

#### POST `/api/events/<event_id>/rsvp`
RSVP to an event (requires authentication)

#### POST `/api/events/`
Create event (admin only)

#### PUT `/api/events/<event_id>`
Update event (admin only)

#### DELETE `/api/events/<event_id>`
Delete event (admin only)

### Media Endpoints

#### GET `/api/media/`
Get published media items
- Query parameters: `page`, `per_page`, `type`

#### GET `/api/media/<media_id>`
Get specific media item

#### POST `/api/media/`
Create media item (admin only)

#### PUT `/api/media/<media_id>`
Update media item (admin only)

#### DELETE `/api/media/<media_id>`
Delete media item (admin only)

### Document Endpoints

#### GET `/api/documents/`
Get accessible documents (requires authentication)

#### GET `/api/documents/<document_id>`
Get specific document (requires authentication)

#### POST `/api/documents/`
Create document (admin only)

#### PUT `/api/documents/<document_id>`
Update document (admin only)

#### DELETE `/api/documents/<document_id>`
Delete document (admin only)

### Admin Endpoints

#### GET `/api/admin/dashboard`
Get dashboard statistics (admin only)

#### GET `/api/admin/analytics`
Get analytics data (admin only)

#### POST `/api/admin/content-push`
Push content to users (admin only)

#### GET `/api/admin/system-health`
Get system health status (admin only)

## Database Models

### User
- `id`: Unique identifier
- `phone`: Phone number (unique)
- `name`: User's full name
- `role`: User role (public, cadre, admin)
- `region`: User's region
- `enrollment_date`: When user joined
- `is_active`: Account status

### NewsItem
- `id`: Unique identifier
- `title_en/te`: Title in English/Telugu
- `description_en/te`: Description in English/Telugu
- `image_url`: Featured image URL
- `category`: News category
- `is_published`: Publication status

### Event
- `id`: Unique identifier
- `title_en/te`: Title in English/Telugu
- `description_en/te`: Description in English/Telugu
- `event_date`: Event date and time
- `location_en/te`: Location in English/Telugu
- `image_url`: Event image URL
- `rsvp_count`: Number of RSVPs
- `is_published`: Publication status

### MediaItem
- `id`: Unique identifier
- `type`: Media type (photo/video)
- `url`: Media file URL
- `thumbnail_url`: Thumbnail URL
- `title_en/te`: Title in English/Telugu
- `is_published`: Publication status

### Document
- `id`: Unique identifier
- `title_en/te`: Title in English/Telugu
- `category`: Document category
- `file_url`: Document file URL
- `access_level`: JSON array of allowed roles
- `is_published`: Publication status

## Configuration

### Environment Variables
- `SECRET_KEY`: Flask secret key
- `JWT_SECRET_KEY`: JWT signing key
- `DATABASE_URL`: Database connection string
- `FLASK_ENV`: Environment (development/production)
- `FLASK_DEBUG`: Debug mode
- `SMS_API_KEY`: SMS service API key
- `MAIL_SERVER`: Email server configuration

### Database Configuration
- **Development**: SQLite database
- **Production**: PostgreSQL recommended

## Security Features

- **JWT Authentication**: Secure token-based authentication
- **Role-based Access Control**: Different access levels for users
- **Input Validation**: Comprehensive input validation
- **CORS Configuration**: Proper CORS setup for frontend integration
- **SQL Injection Protection**: SQLAlchemy ORM prevents SQL injection

## Deployment

### Development
```bash
python app.py
```

### Production
1. Set up production database (PostgreSQL)
2. Configure environment variables
3. Use WSGI server (Gunicorn)
4. Set up reverse proxy (Nginx)
5. Enable HTTPS

### Docker Deployment
```bash
# Build image
docker build -t telangana-congress-api .

# Run container
docker run -p 5000:5000 telangana-congress-api
```

## Testing

### Running Tests
```bash
python -m pytest tests/
```

### Test Coverage
- Unit tests for models and utilities
- Integration tests for API endpoints
- Authentication and authorization tests

## Monitoring & Logging

- **Health Check**: `/api/health` endpoint
- **System Health**: `/api/admin/system-health` (admin only)
- **Error Logging**: Comprehensive error logging
- **Performance Monitoring**: Request timing and database queries

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions, please contact the development team or create an issue in the repository.
