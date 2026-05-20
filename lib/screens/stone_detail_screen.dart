import 'package:flutter/material.dart';
import '../models/stone.dart';

class StoneDetailScreen extends StatelessWidget {
  final Stone stone;

  const StoneDetailScreen({super.key, required this.stone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(stone.title),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stone.imageUrl != null)
              Image.network(
                stone.imageUrl!,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                color: Colors.brown[100],
                child: const Icon(Icons.image_not_supported,
                    size: 64, color: Colors.brown),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stone.title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(stone.description,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(
                    '📍 ${stone.lat.toStringAsFixed(5)}, ${stone.lng.toStringAsFixed(5)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
