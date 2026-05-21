import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_model.dart';

class AppState {
  static final ValueNotifier<LatLng?> mapJumpTarget = ValueNotifier(null);
  static final ValueNotifier<int> bottomNavIndex = ValueNotifier(0);
  static final ValueNotifier<UserModel?> currentProfile = ValueNotifier(null);
}
