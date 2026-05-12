# Telangana Congress Communication App - Flutter Frontend

A Flutter mobile application for the Telangana Congress Communication App, providing both mobile user interface and admin dashboard functionality.

## Features

### Mobile App Features
- **Splash Screen**: Welcome screen with app branding
- **OTP Login**: Phone number-based authentication with OTP verification
- **Language Selection**: Support for English and Telugu languages
- **Home Dashboard**: Overview of news, events, and quick actions
- **Media Gallery**: Photo and video gallery with filtering
- **Events Calendar**: View and RSVP to upcoming events
- **Membership Form**: Join the Congress party
- **Document Center**: Access to party documents based on user role
- **Feedback Form**: Submit feedback and suggestions

### Admin Dashboard Features
- **Admin Dashboard**: Overview of users, content, and analytics
- **User Management**: Manage users, roles, and permissions
- **Content Push**: Send notifications and updates to users
- **Event Management**: Create and manage events
- **Analytics**: View usage statistics and trends
- **Document Upload**: Upload and manage documents

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── index.dart           # Data models (User, NewsItem, Event, etc.)
├── screens/
│   ├── mobile/              # Mobile app screens
│   │   ├── splash_screen.dart
│   │   ├── otp_login_screen.dart
│   │   ├── language_selection_screen.dart
│   │   ├── mobile_home_screen.dart
│   │   └── media_gallery_screen.dart
│   └── admin/               # Admin dashboard screens
│       ├── admin_dashboard_screen.dart
│       └── user_management_screen.dart
├── widgets/
│   └── mobile_nav_bar.dart  # Mobile navigation component
└── services/
    └── auth_service.dart    # Authentication service
```

## Getting Started

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / VS Code
- Android/iOS device or emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd flutter_frontend
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Dependencies

- `http`: For API communication
- `provider`: For state management
- `shared_preferences`: For local storage
- `cached_network_image`: For image caching
- `go_router`: For navigation
- `flutter_svg`: For SVG support
- `intl`: For date formatting

## Configuration

### API Configuration
Update the API base URL in your services to point to your Flask backend:

```dart
const String API_BASE_URL = 'http://your-backend-url:5000/api';
```

### Language Support
The app supports both English and Telugu languages. Language switching is handled through the `LanguageSelectionScreen`.

## Features Implementation Status

### ✅ Completed
- Basic app structure and navigation
- Splash screen with animations
- OTP login flow
- Language selection
- Mobile home screen with quick actions
- Media gallery with filtering
- Admin dashboard with statistics
- User management interface

### 🚧 In Progress
- Event calendar implementation
- Membership form
- Document center
- Feedback form
- Content push functionality
- Analytics dashboard

### 📋 Planned
- Push notifications
- Offline support
- Image upload functionality
- Advanced filtering and search
- User profile management

## Development Guidelines

### Code Style
- Follow Flutter/Dart conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent indentation

### State Management
- Use Provider for state management
- Keep state as local as possible
- Use ChangeNotifier for reactive updates

### UI/UX Guidelines
- Follow Material Design principles
- Ensure responsive design for different screen sizes
- Use consistent color scheme (Congress blue theme)
- Implement proper loading states and error handling

## Testing

### Running Tests
```bash
flutter test
```

### Test Coverage
- Unit tests for services and utilities
- Widget tests for UI components
- Integration tests for user flows

## Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

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