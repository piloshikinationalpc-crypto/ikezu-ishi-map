import 'package:flutter/material.dart';
import '../services/app_state.dart';
import 'map_screen.dart';
import 'list_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    AppState.bottomNavIndex.addListener(_onNavChanged);
    AppState.mapJumpTarget.addListener(_onMapJump);
  }

  void _onNavChanged() {
    setState(() {});
  }

  void _onMapJump() {
    if (AppState.mapJumpTarget.value != null) {
      setState(() => AppState.bottomNavIndex.value = 0);
    }
  }

  @override
  void dispose() {
    AppState.bottomNavIndex.removeListener(_onNavChanged);
    AppState.mapJumpTarget.removeListener(_onMapJump);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = AppState.bottomNavIndex.value;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          MapScreen(),
          ListScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        selectedItemColor: Colors.brown,
        onTap: (i) => setState(() => AppState.bottomNavIndex.value = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '地図'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '一覧'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
        ],
      ),
    );
  }
}
