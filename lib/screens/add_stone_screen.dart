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
  LatLng? _selectedLocation;
  File? _imageFile;
  bool _isLoading = false;
  String _selectedCategory = kStoneCategories.first;
  int _ikezuDegree = 1;

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
      setState(() {
        _selectedLocation = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
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
      String? imageUrl;
      if (_imageFile != null) {
        final compressed = await _compressImage(_imageFile!) ?? _imageFile!;
        final ref = FirebaseStorage.instance
            .ref()
            .child('stones/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(compressed);
        imageUrl = await ref.getDownloadURL();
      }

      final address = await _fetchAddress(_selectedLocation!);

      await FirebaseFirestore.instance.collection('stones').add({
        'title': _titleController.text,
        'description': _descController.text,
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
        'category': _selectedCategory,
        'ikezuDegree': _ikezuDegree,
        'likeCount': 0,
        'likedBy': [],
        'address': address,
        'createdBy': AuthService.currentUid,
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
              children: kStoneCategories.map((cat) {
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
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('いけず度', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(3, (i) {
                final degree = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _ikezuDegree = degree),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '🪨',
                      style: TextStyle(
                        fontSize: 32,
                        color: degree <= _ikezuDegree
                            ? Colors.brown
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                );
              }),
              // ignore: dead_code
            ),
            const SizedBox(height: 16),
            const Text('場所 *', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation ?? const LatLng(35.6812, 139.7671),
                  zoom: 15,
                ),
                markers: _selectedLocation != null
                    ? {Marker(markerId: const MarkerId('sel'), position: _selectedLocation!)}
                    : {},
                onTap: (latLng) => setState(() => _selectedLocation = latLng),
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
            const Text('写真', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_imageFile!, height: 180, fit: BoxFit.cover,
                    width: double.infinity),
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
