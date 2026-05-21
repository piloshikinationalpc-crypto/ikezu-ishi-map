import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/stone.dart';
import '../models/user_model.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'stone_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _avatarUploading = false;

  Future<void> _editNickname(UserModel profile) async {
    final controller = TextEditingController(text: profile.nickname);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ニックネームを変更'),
        content: TextField(
          controller: controller,
          maxLength: 20,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ニックネーム'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存', style: TextStyle(color: Colors.brown)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await UserService.saveNickname(result);
    }
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _avatarUploading = true);
    try {
      await UserService.uploadAvatar(File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('サインアウト'),
        content: const Text('サインアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('サインアウト', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'サインアウト',
            onPressed: _signOut,
          ),
        ],
      ),
      body: ValueListenableBuilder<UserModel?>(
        valueListenable: AppState.currentProfile,
        builder: (context, profile, _) {
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              _buildProfileHeader(profile),
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '自分の投稿',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildMyStones(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserModel profile) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          GestureDetector(
            onTap: _changeAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.brown[100],
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          profile.nickname.isNotEmpty
                              ? profile.nickname[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 32, color: Colors.brown),
                        )
                      : null,
                ),
                if (_avatarUploading)
                  const Positioned.fill(
                    child: CircleAvatar(
                      backgroundColor: Colors.black38,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.brown,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.nickname,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _editNickname(profile),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('ニックネームを変更'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.brown,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStones() {
    final uid = AuthService.currentUid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stones')
          .where('createdBy', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('まだ投稿がありません', style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final stone = Stone.fromFirestore(docs[i]);
            return ListTile(
              leading: stone.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        stone.imageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.brown[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.landscape, color: Colors.brown, size: 24),
                    ),
              title: Text(stone.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(stone.category,
                  style: TextStyle(color: Colors.brown[700], fontSize: 12)),
              trailing: Text('🪨' * stone.ikezuDegree,
                  style: const TextStyle(fontSize: 12)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoneDetailScreen(stone: stone),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
