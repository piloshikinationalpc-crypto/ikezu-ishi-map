import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kStoneCategories = [
  '埋め込み型',
  '置き石型',
  '連続型',
  '大型石',
  '装飾型',
  '複合型',
  'その他',
];

class Stone {
  final String id;
  final String title;
  final String description;
  final double lat;
  final double lng;
  final List<String> imageUrls;
  final DateTime createdAt;
  final String category;
  final int ikezuDegree;
  final int likeCount;
  final List<String> likedBy;
  final String? address;
  final String createdBy;
  final bool isExisting;

  // 後方互換: 旧データの単一 imageUrl もサポート
  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  Stone({
    required this.id,
    required this.title,
    required this.description,
    required this.lat,
    required this.lng,
    this.imageUrls = const [],
    required this.createdAt,
    required this.category,
    required this.ikezuDegree,
    this.likeCount = 0,
    this.likedBy = const [],
    this.address,
    required this.createdBy,
    this.isExisting = true,
  });

  factory Stone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final oldUrl = data['imageUrl'] as String?;
    final rawUrls = data['imageUrls'];
    final imageUrls = rawUrls != null
        ? List<String>.from(rawUrls as List)
        : (oldUrl != null ? [oldUrl] : <String>[]);

    return Stone(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      imageUrls: imageUrls,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      category: data['category'] ?? 'その他',
      ikezuDegree: (data['ikezuDegree'] as num?)?.toInt() ?? 1,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      address: data['address'],
      createdBy: data['createdBy'] ?? '',
      isExisting: data['isExisting'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'lat': lat,
      'lng': lng,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'category': category,
      'ikezuDegree': ikezuDegree,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'address': address,
      'createdBy': createdBy,
      'isExisting': isExisting,
    };
  }
}
