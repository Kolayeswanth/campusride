# CampusRide Agent Instructions

## Build/Test Commands
- **Build**: `flutter build apk` or `flutter build web`
- **Test**: `flutter test` (all tests) or `flutter test test/widget_test.dart` (single test)
- **Analyze**: `flutter analyze` (lints and errors)
- **Format**: `dart format lib/ test/`
- **Dependencies**: `flutter pub get`
- **Code generation**: `flutter packages pub run build_runner build`

## Code Style Guidelines
- **Imports**: Group imports as: dart/flutter, package imports, relative imports
- **Classes**: Use PascalCase, extend StatelessWidget/StatefulWidget for widgets
- **Variables**: Use camelCase, prefer final/const where possible
- **Documentation**: Use `///` for public APIs, include parameter descriptions
- **Naming**: Use descriptive names (e.g., `CustomButton`, `AuthService`)
- **Files**: Use snake_case for file names, organize by feature folders
- **Error handling**: Use try-catch blocks, provide meaningful error messages
- **State management**: Use Provider pattern with ChangeNotifier services
- **Architecture**: Feature-based folder structure under lib/features/
- **Constants**: Define in separate files, use static const for values
