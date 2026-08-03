import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import '../models/stone.dart';
import '../services/app_state.dart';
import 'stone_detail_screen.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  String? _filterCategory;
  Position? _currentPosition;
  bool _sortByDistance = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentPosition();
  }

  // showFeedback: 引っ張って更新から呼ばれたときだけ結果をSnackBarで知らせる
  Future<void> _fetchCurrentPosition({bool showFeedback = false}) async {
    String message;
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        message = '位置情報が許可されていないため、距離は表示できません';
      } else {
        final pos = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        setState(() => _currentPosition = pos);
        message = '現在地を更新しました';
      }
    } catch (_) {
      message = '現在地を取得できませんでした';
    }
    if (!mounted || !showFeedback) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  double _distanceTo(Stone stone) {
    if (_currentPosition == null) return double.infinity;
    const R = 6371000.0;
    final lat1 = _currentPosition!.latitude * pi / 180;
    final lat2 = stone.lat * pi / 180;
    final dLat = (stone.lat - _currentPosition!.latitude) * pi / 180;
    final dLng = (stone.lng - _currentPosition!.longitude) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String _formatDistance(double meters) {
    if (meters == double.infinity) return '';
    if (meters < 1000) return '${meters.toInt()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('いけず石一覧'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          if (_currentPosition != null)
            IconButton(
              icon: Icon(
                _sortByDistance ? Icons.near_me : Icons.near_me_outlined,
              ),
              tooltip: '近い順',
              onPressed: () =>
                  setState(() => _sortByDistance = !_sortByDistance),
            ),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (val) => setState(() => _filterCategory = val),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('すべて')),
              ...kStoneCategories.map(
                (cat) => PopupMenuItem(value: cat, child: Text(cat)),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stones')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.brown),
                  SizedBox(height: 16),
                  Text(
                    '読み込みに失敗しました',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '通信環境を確認してください',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.brown),
                  SizedBox(height: 16),
                  Text(
                    'まだ登録されていません',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          var stones = snapshot.data!.docs
              .map((doc) => Stone.fromFirestore(doc))
              .where(
                (s) =>
                    _filterCategory == null ||
                    s.categories.contains(_filterCategory),
              )
              .toList();

          if (_sortByDistance && _currentPosition != null) {
            stones.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.brown[50],
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Text(
                      _filterCategory == null
                          ? '全 ${stones.length} 件'
                          : 'フィルター: $_filterCategory（${stones.length} 件）',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Spacer(),
                    if (_filterCategory != null)
                      TextButton(
                        onPressed: () => setState(() => _filterCategory = null),
                        child: const Text('解除'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _fetchCurrentPosition(showFeedback: true),
                  child: stones.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.brown,
                            ),
                            SizedBox(height: 16),
                            Center(
                              child: Text(
                                '該当するいけず石はありません',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: AppState.showAds
                              ? stones.length + (stones.length ~/ 5)
                              : stones.length,
                          itemBuilder: (context, index) {
                            if (AppState.showAds && (index + 1) % 6 == 0) {
                              return const _BannerAdItem();
                            }
                            final stoneIndex = AppState.showAds
                                ? index - (index ~/ 6)
                                : index;
                            if (stoneIndex >= stones.length) {
                              return const SizedBox.shrink();
                            }
                            final stone = stones[stoneIndex];
                            final dist = _distanceTo(stone);
                            return ListTile(
                              leading: stone.imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        stone.imageUrl!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.brown[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.landscape,
                                        color: Colors.brown,
                                      ),
                                    ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stone.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '🪨' * stone.ikezuDegree,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stone.category,
                                    style: TextStyle(
                                      color: Colors.brown[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (dist != double.infinity)
                                    Text(
                                      _formatDistance(dist),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.thumb_up,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 2),
                                  Text('${stone.likeCount}'),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StoneDetailScreen(stone: stone),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BannerAdItem extends StatefulWidget {
  const _BannerAdItem();

  @override
  State<_BannerAdItem> createState() => _BannerAdItemState();
}

class _BannerAdItemState extends State<_BannerAdItem> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: AppState.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      height: _ad!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _ad!),
    );
  }
}
