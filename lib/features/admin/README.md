# Admin Module

This module contains all features and screens for Super Admin management, including:

- Super Admin secure login (hidden route)
- College management (add, edit, list colleges)
- Driver management (nested under colleges)
- Predefined route management (define, assign to colleges)

## Structure

- `colleges/` — College management screens, models, services
- `drivers/` — Driver management screens, models, services
- `routes/` — Route management screens, models, services
- `screens/` — Super Admin dashboard, login, navigation
- `widgets/` — Shared widgets for admin UI

All admin features are accessible only after Super Admin login. 