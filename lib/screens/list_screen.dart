import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/stone.dart';
import 'stone_detail_screen.dart';

class ListScreen extends StatelessWidget {
  const ListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('いけず石一覧'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stones')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
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
                  Text('まだ登録されていません', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final stones = snapshot.data!.docs
              .map((doc) => Stone.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: stones.length,
            itemBuilder: (context, index) {
              final stone = stones[index];
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
                        child: const Icon(Icons.landscape, color: Colors.brown),
                      ),
                title: Text(stone.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  stone.description.isNotEmpty ? stone.description : '説明なし',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => StoneDetailScreen(stone: stone)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
