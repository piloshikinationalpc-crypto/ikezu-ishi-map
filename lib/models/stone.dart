import 'package:cloud_firestore/cloud_firestore.dart';

class Stone {
  final String id;
  final String title;
  final String description;
  final double lat;
  final double lng;
  final String? imageUrl;
  final DateTime createdAt;

  Stone({
    required this.id,
    required this.title,
    required this.description,
    required this.lat,
    required this.lng,
    this.imageUrl,
    required this.createdAt,
  });

  factory Stone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Stone(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'lat': lat,
      'lng': lng,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
