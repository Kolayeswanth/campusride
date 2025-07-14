# CampusRide - College Bus Tracking App

CampusRide is a modern Flutter application that provides real-time tracking of college buses and helps students plan their journeys efficiently. The app features a sleek UI with glassmorphic elements and smooth animations.

## Features

### For Passengers
- Real-time bus tracking with accurate ETAs
- Favorite routes and stops
- Push notifications for bus arrivals
- Trip planning and history
- Search functionality for routes and stops

### For Drivers
- Live location broadcasting
- Trip management (start/end trips)
- Passenger count tracking
- Route visualization
- Trip statistics

### Database & Backend
- Supabase database integration
- Authentication with email/password and Google Sign-In
- Real-time location updates
- Route management system
- Schema cache management utilities

## Technical Stack

- **Frontend**: Flutter with Material Design 3
- **Backend**: Supabase for authentication, database, and real-time functionality
- **Maps**: Google Maps integration for location tracking
- **Authentication**: Email/password and Google Sign-In
- **Notifications**: Firebase Cloud Messaging

## Design System

The app follows a consistent design system with:
- Pastel color palette with blue and purple accent colors
- Glassmorphic UI elements for a modern look
- Fluid animations and transitions
- Responsive layouts for different device sizes

## Font Pairing Suggestions

The app uses the following font pairings that complement the pastel design:

### Primary Pairing (Currently Implemented)
- **Headings**: Montserrat - A geometric sans-serif typeface with clean lines that adds a modern touch
- **Body**: Poppins - A geometric sans-serif with rounded terminals that offers excellent readability

### Alternative Pairings

#### Option 1: Elegant and Professional
- **Headings**: Playfair Display - A serif font with stylish high-contrast design
- **Body**: Source Sans Pro - A humanist sans-serif with excellent readability

#### Option 2: Modern and Friendly
- **Headings**: Nunito - A well-balanced sans-serif with rounded terminals
- **Body**: Open Sans - A humanist sans-serif designed for legibility on screens

#### Option 3: Clean and Contemporary
- **Headings**: Quicksand - A sans-serif with rounded terminals and geometric structure
- **Body**: Roboto - A neo-grotesque sans-serif with natural reading rhythm

## Project Structure

```
lib/
├── core/
│   ├── config/
│   ├── constants/
│   ├── services/
│   ├── theme/
│   └── utils/
├── features/
│   ├── auth/
│   ├── driver/
│   ├── map/
│   ├── notifications/
│   └── passenger/
├── shared/
│   ├── animations/
│   ├── extensions/
│   ├── models/
│   └── widgets/
└── assets/
    ├── animations/
    ├── icons/
    └── images/
```

## Getting Started

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure your Supabase credentials in `lib/core/config/app_config.dart`
4. Run the app with `flutter run`

## Development Phases

### Phase 1: Project Setup & UI Design System ✅
- Project structure creation
- Supabase integration setup
- Design system implementation
- Custom UI components

### Phase 2: Authentication & Role Selection ✅
- Supabase authentication service
- Google Sign-In integration
- Registration and login flows
- Password reset functionality
- Role selection (Driver/Passenger)
- Session management with Provider

### Phase 3: Driver Features ✅
- Trip management (start/end)
- Location tracking with Geolocator
- Google Maps integration for route display
- Driver dashboard with real-time stats
- Trip history view

### Phase 4: Passenger Features ⏳
- Bus tracking interface
- Favorite routes management
- Search functionality
- ETA calculations
- Bus stop information display

### Phase 5: Notifications & Alerts
- Real-time trip updates
- Bus arrival notifications
- Driver announcements
- Delay alerts

### Phase 6: Offline Support & Caching
- Offline storage for trip data
- Route caching
- Background location updates
- Sync mechanisms

### Phase 7: Analytics & Reporting
- Trip statistics
- Usage patterns
- Performance metrics
- Driver efficiency reporting

### Phase 8: Next Phase
- [ ] Real-time bus tracking
- [ ] Favorite routes
- [ ] Trip history
- [ ] Notifications

## Developer Documentation

### Schema Management
The app uses Supabase with proper schema management. Database schema files are located in:

- `lib/core/data/public_schema.sql` - Main database schema
- `lib/core/data/realtime_tables_schema.sql` - Realtime configuration schema

For database troubleshooting, check the Flutter debug console for any schema-related errors.
