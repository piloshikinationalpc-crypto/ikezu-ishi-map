import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/stone.dart';
import 'map_picker_screen.dart';

class EditStoneScreen extends StatefulWidget {
  final Stone stone;
  const EditStoneScreen({super.key, required this.stone});

  @override
  State<EditStoneScreen> createState() => _EditStoneScreenState();
}

class _EditStoneScreenState extends State<EditStoneScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late LatLng _selectedLocation;
  late List<String> _keptUrls;
  final List<File> _newFiles = [];
  bool _isLoading = false;
  late Set<String> _selectedCategories;
  late int _ikezuDegree;
  late bool _isExisting;
  final List<String> _extraCategories = [];

  List<String> get _allCategories {
    final base = [...kStoneCategories, ..._extraCategories];
    for (final cat in _selectedCategories) {
      if (!base.contains(cat)) base.add(cat);
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    final s = widget.stone;
    _titleController = TextEditingController(text: s.title);
    _descController = TextEditingController(text: s.description);
    _selectedLocation = LatLng(s.lat, s.lng);
    _keptUrls = List.from(s.imageUrls);
    _selectedCategories = Set.from(s.categories);
    _ikezuDegree = s.ikezuDegree;
    _isExisting = s.isExisting;
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('カテゴリーを追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'カテゴリー名'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('追加', style: TextStyle(color: Colors.brown)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() {
        _extraCategories.add(result);
        if (_selectedCategories.length < 3) _selectedCategories.add(result);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final total = _keptUrls.length + _newFiles.length;
    if (total >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真は最大5枚まで登録できます')),
      );
      return;
    }
    final picker = ImagePicker();
    if (source == ImageSource.gallery) {
      final remaining = 5 - total;
      final picked = await picker.pickMultiImage(limit: remaining);
      if (picked.isNotEmpty) {
        setState(() => _newFiles.addAll(picked.map((x) => File(x.path))));
      }
    } else {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() => _newFiles.add(File(picked.path)));
      }
    }
  }

  Future<File?> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 1080,
      minHeight: 1080,
    );
    return result != null ? File(result.path) : null;
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 途中で失敗したときに消すため、アップロード済みの分を控えておく。
    // 消さずに放置すると、どこからも参照されない画像がStorageに溜まり続けて課金だけ増える。
    final uploaded = <Reference>[];
    try {
      final newUrls = <String>[];
      for (final file in _newFiles) {
        final compressed = await _compressImage(file) ?? file;
        final ref = FirebaseStorage.instance
            .ref()
            .child('stones/${DateTime.now().millisecondsSinceEpoch}_${newUrls.length}.jpg');
        await ref.putFile(compressed);
        uploaded.add(ref);
        newUrls.add(await ref.getDownloadURL());
      }

      await FirebaseFirestore.instance
          .collection('stones')
          .doc(widget.stone.id)
          .update({
        'title': _titleController.text,
        'description': _descController.text,
        'lat': _selectedLocation.latitude,
        'lng': _selectedLocation.longitude,
        'categories': _selectedCategories.toList(),
        'ikezuDegree': _ikezuDegree,
        'isExisting': _isExisting,
        'imageUrls': [..._keptUrls, ...newUrls],
      });

      uploaded.clear(); // Firestoreまで通ったので後始末は不要
      if (mounted) Navigator.pop(context);
    } catch (e) {
      for (final ref in uploaded) {
        try {
          await ref.delete();
        } catch (_) {
          // 消せなくても更新失敗の通知は出す
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPhotos = _keptUrls.length + _newFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('いけず石を編集'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '説明',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('カテゴリー', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('(最大3つまで)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ..._allCategories.map((cat) {
                  final selected = _selectedCategories.contains(cat);
                  return FilterChip(
                    label: Text(cat),
                    selected: selected,
                    selectedColor: Colors.brown,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          if (_selectedCategories.length < 3) _selectedCategories.add(cat);
                        } else {
                          if (_selectedCategories.length > 1) _selectedCategories.remove(cat);
                        }
                      });
                    },
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16, color: Colors.brown),
                  label: const Text('追加'),
                  side: const BorderSide(color: Colors.brown),
                  onPressed: _addCategory,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('いけず度', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(3, (i) {
                final degree = i + 1;
                final active = degree <= _ikezuDegree;
                return GestureDetector(
                  onTap: () => setState(() => _ikezuDegree = degree),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: active ? Colors.brown[100] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? Colors.brown : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Opacity(
                      opacity: active ? 1.0 : 0.3,
                      child: const Text('🪨', style: TextStyle(fontSize: 32)),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('現存状況', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isExisting = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isExisting ? Colors.green[100] : Colors.grey[100],
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                        border: Border.all(
                          color: _isExisting ? Colors.green : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '✅ 現存する',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isExisting ? Colors.green[800] : Colors.grey,
                          fontWeight: _isExisting ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isExisting = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isExisting ? Colors.red[100] : Colors.grey[100],
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                        border: Border.all(
                          color: !_isExisting ? Colors.red : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '❌ 現存しない',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_isExisting ? Colors.red[800] : Colors.grey,
                          fontWeight: !_isExisting ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('場所', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapPickerScreen(initialLocation: _selectedLocation),
                  ),
                );
                if (result != null) setState(() => _selectedLocation = result);
              },
              child: Stack(
                children: [
                  SizedBox(
                    height: 220,
                    child: AbsorbPointer(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _selectedLocation,
                          zoom: 16,
                        ),
                        markers: {
                          Marker(markerId: const MarkerId('sel'), position: _selectedLocation),
                        },
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        onMapCreated: (_) {},
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.brown,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_full, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('タップで拡大', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '📍 ${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('写真', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('($totalPhotos/5枚)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            if (totalPhotos > 0)
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // 既存の画像
                    ...List.generate(_keptUrls.length, (i) => Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _keptUrls[i],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => setState(() => _keptUrls.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    )),
                    // 新規追加画像
                    ...List.generate(_newFiles.length, (i) => Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _newFiles[i],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => setState(() => _newFiles.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    )),
                  ],
                ),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('撮影'),
                ),
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('ギャラリー'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('更新する', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
