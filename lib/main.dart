import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'screens/home_screen.dart';
import 'services/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/nickname_screen.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  FlutterNativeSplash.remove();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'いけず石マップ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _user;
  UserModel? _profile;
  bool _authLoading = true;
  bool _profileLoading = true;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserModel?>? _profileSub;

  @override
  void initState() {
    super.initState();
    _authSub = AuthService.authStateChanges.listen((user) {
      if (!mounted) return;
      setState(() {
        _user = user;
        _authLoading = false;
      });
      _listenToProfile(user);
    });
  }

  void _listenToProfile(User? user) {
    _profileSub?.cancel();
    setState(() {
      _profile = null;
      _profileLoading = user != null;
    });
    if (user == null) return;
    _profileSub = UserService.currentProfileStream().listen((profile) {
      if (!mounted) return;
      AppState.currentProfile.value = profile;
      setState(() {
        _profile = profile;
        _profileLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_authLoading || (_user != null && _profileLoading)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) return const LoginScreen();
    if (_profile == null || _profile!.nickname.isEmpty) return const NicknameScreen();
    return const HomeScreen();
  }
}
