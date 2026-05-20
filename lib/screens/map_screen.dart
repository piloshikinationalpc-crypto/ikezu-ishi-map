import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/stone.dart';
import '../services/app_state.dart';
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
  BitmapDescriptor? _stoneIcon;
  List<DocumentSnapshot> _latestDocs = [];
  static const LatLng _defaultPosition = LatLng(35.6812, 139.7671);

  @override
  void initState() {
    super.initState();
    _loadMarkerIcon();
    _loadStones();
    _moveToCurrentLocation();
    AppState.mapJumpTarget.addListener(_onJumpTarget);
  }

  @override
  void dispose() {
    AppState.mapJumpTarget.removeListener(_onJumpTarget);
    super.dispose();
  }

  void _onJumpTarget() {
    final target = AppState.mapJumpTarget.value;
    if (target != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 17),
      );
      AppState.mapJumpTarget.value = null;
    }
  }

  Future<void> _loadMarkerIcon() async {
    final icon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icon/marker.png',
    );
    setState(() => _stoneIcon = icon);
    _buildMarkers(_latestDocs);
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
      _latestDocs = snap.docs;
      _buildMarkers(_latestDocs);
    });
  }

  void _buildMarkers(List<DocumentSnapshot> docs) {
    final markers = <Marker>{};
    for (final doc in docs) {
      try {
        final stone = Stone.fromFirestore(doc);
        markers.add(Marker(
          markerId: MarkerId(stone.id),
          position: LatLng(stone.lat, stone.lng),
          icon: _stoneIcon ?? BitmapDescriptor.defaultMarker,
          consumeTapEvents: true,
          onTap: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StoneDetailScreen(stone: stone)),
            );
          },
        ));
      } catch (_) {}
    }
    setState(() => _markers
      ..clear()
      ..addAll(markers));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('いけず石マップ'),
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
        onMapCreated: (controller) {
          _mapController = controller;
          _onJumpTarget();
        },
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
