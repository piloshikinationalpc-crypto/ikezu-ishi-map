import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/stone.dart';
import '../services/auth_service.dart';

class AddStoneScreen extends StatefulWidget {
  const AddStoneScreen({super.key});

  @override
  State<AddStoneScreen> createState() => _AddStoneScreenState();
}

class _AddStoneScreenState extends State<AddStoneScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  final List<File> _imageFiles = [];
  bool _isLoading = false;
  String _selectedCategory = kStoneCategories.first;
  int _ikezuDegree = 1;
  bool _isExisting = true;
  final List<String> _extraCategories = [];

  List<String> get _allCategories => [...kStoneCategories, ..._extraCategories];

  @override
  void initState() {
    super.initState();
    _setCurrentLocation();
  }

  Future<void> _setCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) { return; }
      final pos = await Geolocator.getCurrentPosition();
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() => _selectedLocation = target);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    } catch (_) {}
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
        _selectedCategory = result;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_imageFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真は最大5枚まで登録できます')),
      );
      return;
    }
    final picker = ImagePicker();
    if (source == ImageSource.gallery) {
      final remaining = 5 - _imageFiles.length;
      final picked = await picker.pickMultiImage(limit: remaining);
      if (picked.isNotEmpty) {
        setState(() => _imageFiles.addAll(picked.map((x) => File(x.path))));
      }
    } else {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() => _imageFiles.add(File(picked.path)));
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

  Future<String?> _fetchAddress(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return [p.administrativeArea, p.locality, p.subLocality, p.thoroughfare]
            .where((s) => s != null && s.isNotEmpty)
            .join('');
      }
    } catch (_) {}
    return null;
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルと場所を入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageUrls = <String>[];
      for (final file in _imageFiles) {
        final compressed = await _compressImage(file) ?? file;
        final ref = FirebaseStorage.instance
            .ref()
            .child('stones/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.jpg');
        await ref.putFile(compressed);
        imageUrls.add(await ref.getDownloadURL());
      }

      final address = await _fetchAddress(_selectedLocation!);

      await FirebaseFirestore.instance.collection('stones').add({
        'title': _titleController.text,
        'description': _descController.text,
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'imageUrls': imageUrls,
        'createdAt': Timestamp.now(),
        'category': _selectedCategory,
        'ikezuDegree': _ikezuDegree,
        'likeCount': 0,
        'likedBy': [],
        'address': address,
        'createdBy': AuthService.currentUid,
        'isExisting': _isExisting,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('いけず石を登録'),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ..._allCategories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    selectedColor: Colors.brown,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
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
            const Text('場所 *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation ?? const LatLng(35.6812, 139.7671),
                  zoom: 16,
                ),
                markers: _selectedLocation != null
                    ? {Marker(markerId: const MarkerId('sel'), position: _selectedLocation!)}
                    : {},
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onTap: (latLng) => setState(() => _selectedLocation = latLng),
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (_selectedLocation != null) {
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(_selectedLocation!, 16),
                    );
                  }
                },
              ),
            ),
            if (_selectedLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '📍 ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('写真', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('(最大5枚)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            if (_imageFiles.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageFiles.length,
                  itemBuilder: (_, i) => Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _imageFiles[i],
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
                          onTap: () => setState(() => _imageFiles.removeAt(i)),
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
                  ),
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
                    : const Text('登録する', style: TextStyle(fontSize: 16)),
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
