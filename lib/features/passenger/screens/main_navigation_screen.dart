import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/realtime_service.dart';
import 'passenger_home_content.dart';
import 'live_buses_screen.dart';
import 'favourites_screen.dart';
import '../../auth/screens/profile_screen.dart';

/// Main navigation screen with persistent bottom navbar
class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigationScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Initialize real-time subscriptions for live data updates
  void _initializeRealtimeSubscriptions() {
    
    
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);
    realtimeService.initializeSubscriptions();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// Sign out the user
  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define titles for each tab
    final titles = ['CampusRide', 'Live Buses', 'Favourites', 'Profile'];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: _currentIndex == 0 ? [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Show notifications
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
              const PopupMenuItem(
                value: 'help',
                child: Text('Help & Support'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Sign Out'),
              ),
            ],
          ),
        ] : null,
      ),
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: const [
          PassengerHomeContent(), // Home content without scaffold
          LiveBusesScreen(),       // Live buses screen
          FavouritesScreen(),      // Favourites screen
          ProfileScreen(),         // Profile screen
        ],
      ),
      bottomNavigationBar:        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Colors.grey[600],
            backgroundColor: Colors.white,
            selectedLabelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            iconSize: 20,
            elevation: 0,
            onTap: _onTabTapped,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 20),
                activeIcon: Icon(Icons.home, size: 20, color: AppColors.primary),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.live_tv_outlined, size: 20),
                activeIcon: Icon(Icons.live_tv, size: 20, color: AppColors.primary),
                label: 'Live',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_outline, size: 20),
                activeIcon: Icon(Icons.favorite, size: 20, color: AppColors.primary),
                label: 'Saved',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline, size: 20),
                activeIcon: Icon(Icons.person, size: 20, color: AppColors.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
    );
  }
}
