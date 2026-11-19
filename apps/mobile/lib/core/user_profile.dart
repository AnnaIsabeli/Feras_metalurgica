import 'package:flutter/material.dart';

/// Display information from Google; it never determines access permissions.
class UserProfile {
  const UserProfile({required this.name, required this.email, this.photoUrl});
  final String name;
  final String email;
  final String? photoUrl;
  String get firstName =>
      name.trim().isEmpty ? 'Olá' : name.trim().split(RegExp(r'\s+')).first;
  String? get avatarUrl {
    final uri = Uri.tryParse(photoUrl ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri.toString()
        : null;
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.profile, this.size = 38});
  final UserProfile? profile;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      size <= 48
          ? 'assets/brand/header-profile.png'
          : 'assets/brand/profile-placeholder.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    return Semantics(
      label: profile == null ? 'Perfil' : 'Foto de ${profile!.name}',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: profile?.avatarUrl == null
              ? fallback
              : Image.network(
                  profile!.avatarUrl!,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => fallback,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                ),
        ),
      ),
    );
  }
}
