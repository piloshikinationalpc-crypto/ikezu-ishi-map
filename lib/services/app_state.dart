import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_model.dart';

class AppState {
  static final ValueNotifier<LatLng?> mapJumpTarget = ValueNotifier(null);
  static final ValueNotifier<int> bottomNavIndex = ValueNotifier(0);
  static final ValueNotifier<UserModel?> currentProfile = ValueNotifier(null);

  // 広告表示フラグ: true にすると一覧に広告が挿入される
  static const bool showAds = false;

  // TODO: AdMob審査通過後に本番IDへ差し替える
  static const String adUnitId = 'ca-app-pub-3940256099942544/6300978111'; // テスト用バナー
}
