import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Model representing the authenticated user profile.
class UserProfile {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String accessToken;

  const UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.accessToken,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json, String token) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      accessToken: token,
    );
  }

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
}

/// Global provider for the logged-in user profile.
final authUserProvider = StateProvider<UserProfile?>((ref) => null);
