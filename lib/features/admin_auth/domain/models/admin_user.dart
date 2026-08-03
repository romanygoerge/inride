/// Admin User Domain Model
library;

class AdminUser {
  final String id;
  final String authUserId;
  final String name;
  final String email;
  final String role; // 'super_admin' or 'admin'
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  const AdminUser({
    required this.id,
    required this.authUserId,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.lastLogin,
    this.createdAt,
  });

  /// Check if the admin possesses Super Admin privileges
  bool get isSuperAdmin => role.toLowerCase() == 'super_admin';

  /// Factory constructor to parse JSON data returned from Supabase `admins` table
  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String? ?? '',
      authUserId: json['auth_user_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Admin',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'admin',
      isActive: json['is_active'] as bool? ?? false,
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// Converts object to JSON format for updates/storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Copy instance with modified values
  AdminUser copyWith({
    String? id,
    String? authUserId,
    String? name,
    String? email,
    String? role,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? createdAt,
  }) {
    return AdminUser(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'AdminUser(id: $id, authUserId: $authUserId, name: $name, email: $email, role: $role, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminUser &&
        other.id == id &&
        other.authUserId == authUserId &&
        other.email == email &&
        other.role == role &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(id, authUserId, email, role, isActive);
  }
}
