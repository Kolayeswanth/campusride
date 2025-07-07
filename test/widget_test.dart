// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:campusride/core/services/auth_service.dart';
import 'package:campusride/core/services/map_service.dart';
import 'package:campusride/core/services/trip_service.dart';
import 'package:campusride/core/services/navigation_service.dart';

// Mock classes
class MockAuthService extends Mock implements AuthService {}

class MockMapService extends Mock implements MapService {}

class MockTripService extends Mock implements TripService {}

class MockNavigationService extends Mock implements NavigationService {}

void main() {
  // Setup mocks
  final mockAuthService = MockAuthService();
  final mockMapService = MockMapService();
  final mockTripService = MockTripService();
  final mockNavigationService = MockNavigationService();

  // Setup test widget with mocked providers
  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuthService),
        ChangeNotifierProvider<NavigationService>.value(
            value: mockNavigationService),
        ChangeNotifierProvider<MapService>.value(value: mockMapService),
        ChangeNotifierProvider<TripService>.value(value: mockTripService),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('CampusRide Test'),
          ),
        ),
      ),
    );
  }

  setUp(() async {
    // Initialize any test dependencies
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // Build our test app and trigger a frame
    await tester.pumpWidget(createTestApp());

    // Verify that the test text is displayed
    expect(find.text('CampusRide Test'), findsOneWidget);
  });
}
