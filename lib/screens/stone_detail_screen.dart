import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/stone.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';
import 'comment_screen.dart';
import 'edit_stone_screen.dart';

class StoneDetailScreen extends StatefulWidget {
  final Stone stone;
  const StoneDetailScreen({super.key, required this.stone});

  @override
  State<StoneDetailScreen> createState() => _StoneDetailScreenState();
}

class _StoneDetailScreenState extends State<StoneDetailScreen> {
  late Stone _stone;
  bool _likeLoading = false;
  bool _photoUploading = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _stone = widget.stone;
    _listenToStone();
  }

  void _listenToStone() {
    FirebaseFirestore.instance
        .collection('stones')
        .doc(_stone.id)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _stone = Stone.fromFirestore(doc);
          if (_currentImageIndex >= _stone.imageUrls.length) {
            _currentImageIndex = 0;
          }
        });
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    setState(() => _likeLoading = true);

    final uid = AuthService.currentUid;
    final ref = FirebaseFirestore.instance.collection('stones').doc(_stone.id);
    final liked = _stone.likedBy.contains(uid);

    await ref.update({
      'likeCount': FieldValue.increment(liked ? -1 : 1),
      'likedBy': liked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });

    setState(() => _likeLoading = false);
  }

  Future<void> _deleteStone() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除確認'),
        content: const Text('この石を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance.collection('stones').doc(_stone.id).delete();
    if (mounted) Navigator.pop(context);
  }

  void _viewOnMap() {
    AppState.mapJumpTarget.value = LatLng(_stone.lat, _stone.lng);
    AppState.bottomNavIndex.value = 0;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _showFullScreenPhoto(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhoto(ImageSource source) async {
    if (_stone.imageUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真は最大5枚まで登録できます')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    setState(() => _photoUploading = true);
    try {
      final file = File(picked.path);
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressed = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
      );
      final uploadFile = compressed != null ? File(compressed.path) : file;

      final ref = FirebaseStorage.instance
          .ref()
          .child('stones/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(uploadFile);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('stones').doc(_stone.id).update({
        'imageUrls': FieldValue.arrayUnion([url]),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  void _showAddPhotoSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('撮影'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('ギャラリーから選択'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUid;
    // 投稿者判定: createdBy が空（旧データ）または UID が一致する場合
    final isOwner = _stone.createdBy.isEmpty || _stone.createdBy == uid;
    final liked = _stone.likedBy.contains(uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(_stone.title),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              tooltip: '写真を追加',
              onPressed: _photoUploading ? null : _showAddPhotoSheet,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '編集',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditStoneScreen(stone: _stone)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '削除',
              onPressed: _deleteStone,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像ギャラリー
            if (_stone.imageUrls.isNotEmpty) ...[
              SizedBox(
                height: 260,
                child: PageView.builder(
                  itemCount: _stone.imageUrls.length,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _showFullScreenPhoto(_stone.imageUrls[i]),
                    child: Image.network(
                      _stone.imageUrls[i],
                      width: double.infinity,
                      height: 260,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              if (_stone.imageUrls.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_stone.imageUrls.length, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentImageIndex ? Colors.brown : Colors.grey[300],
                      ),
                    )),
                  ),
                ),
            ] else
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 180,
                    color: Colors.brown[50],
                    child: const Icon(Icons.landscape, size: 64, color: Colors.brown),
                  ),
                  if (_photoUploading)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            if (_photoUploading && _stone.imageUrls.isNotEmpty)
              const LinearProgressIndicator(color: Colors.brown),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_stone.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // 現存状況
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _stone.isExisting ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _stone.isExisting ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Text(
                      _stone.isExisting ? '✅ 現存する' : '❌ 現存しない',
                      style: TextStyle(
                        color: _stone.isExisting ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  // カテゴリー & いけず度
                  Row(
                    children: [
                      Chip(
                        label: Text(_stone.category),
                        backgroundColor: Colors.brown[100],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'いけず度: ${'🪨' * _stone.ikezuDegree}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 住所
                  if (_stone.address != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.place, size: 16, color: Colors.brown),
                        const SizedBox(width: 4),
                        Expanded(child: Text(_stone.address!, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 説明
                  if (_stone.description.isNotEmpty) ...[
                    Text(_stone.description, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                  ],

                  // 登録日時
                  Text(
                    '登録日: ${DateFormat('yyyy年MM月dd日').format(_stone.createdAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  // いいね・コメント・地図ボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          IconButton(
                            onPressed: _likeLoading ? null : _toggleLike,
                            icon: Icon(
                              liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                              color: liked ? Colors.brown : Colors.grey,
                              size: 28,
                            ),
                          ),
                          Text('${_stone.likeCount} いけずやな！',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      Column(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CommentScreen(stoneId: _stone.id),
                              ),
                            ),
                            icon: const Icon(Icons.comment_outlined,
                                color: Colors.grey, size: 28),
                          ),
                          const Text('コメント', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Column(
                        children: [
                          IconButton(
                            onPressed: _viewOnMap,
                            icon: const Icon(Icons.map, color: Colors.brown, size: 28),
                          ),
                          const Text('地図で見る', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
