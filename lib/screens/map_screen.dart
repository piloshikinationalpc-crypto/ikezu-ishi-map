import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/stone.dart';
import 'add_stone_screen.dart';
import 'stone_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  static const LatLng _defaultPosition = LatLng(35.6812, 139.7671); // 東京

  @override
  void initState() {
    super.initState();
    _loadStones();
    _moveToCurrentLocation();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) { return; }

      final pos = await Geolocator.getCurrentPosition();
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
    } catch (_) {}
  }

  void _loadStones() {
    FirebaseFirestore.instance.collection('stones').snapshots().listen((snap) {
      final markers = snap.docs.map((doc) {
        final stone = Stone.fromFirestore(doc);
        return Marker(
          markerId: MarkerId(stone.id),
          position: LatLng(stone.lat, stone.lng),
          infoWindow: InfoWindow(title: stone.title),
          onTap: () => _onMarkerTap(stone),
        );
      }).toSet();

      setState(() => _markers
        ..clear()
        ..addAll(markers));
    });
  }

  void _onMarkerTap(Stone stone) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoneDetailScreen(stone: stone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('全国いけず石マップ'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _defaultPosition,
          zoom: 12,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) => _mapController = controller,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddStoneScreen()),
        ),
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }
}
