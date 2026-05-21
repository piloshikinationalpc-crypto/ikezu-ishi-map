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
  final List<String> categories;
  final int ikezuDegree;
  final int likeCount;
  final List<String> likedBy;
  final String? address;
  final String createdBy;
  final bool isExisting;

  // 後方互換: 旧コードが category (単数) を参照している箇所向け
  String get category => categories.isNotEmpty ? categories.first : 'その他';
  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  Stone({
    required this.id,
    required this.title,
    required this.description,
    required this.lat,
    required this.lng,
    this.imageUrls = const [],
    required this.createdAt,
    this.categories = const ['その他'],
    required this.ikezuDegree,
    this.likeCount = 0,
    this.likedBy = const [],
    this.address,
    required this.createdBy,
    this.isExisting = true,
  });

  factory Stone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // imageUrls: 旧 imageUrl (String) → リストに変換
    final oldUrl = data['imageUrl'] as String?;
    final rawUrls = data['imageUrls'];
    final imageUrls = rawUrls != null
        ? List<String>.from(rawUrls as List)
        : (oldUrl != null ? [oldUrl] : <String>[]);

    // categories: 旧 category (String) → リストに変換
    final oldCat = data['category'] as String?;
    final rawCats = data['categories'];
    final categories = rawCats != null
        ? List<String>.from(rawCats as List)
        : (oldCat != null && oldCat.isNotEmpty ? [oldCat] : ['その他']);

    return Stone(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      imageUrls: imageUrls,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      categories: categories,
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
      'categories': categories,
      'ikezuDegree': ikezuDegree,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'address': address,
      'createdBy': createdBy,
      'isExisting': isExisting,
    };
  }
}
