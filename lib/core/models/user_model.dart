class UserModel {
  final String uid;
  final String name;
  final String phoneNumber;
  final String email;
  final String role; // 'rider' | 'driver'
  final double rating;
  final double walletBalance;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.role,
    required this.rating,
    required this.walletBalance,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    final rawCreated = data['created_at'] ?? data['createdAt'];
    DateTime createdDate = DateTime.now();
    if (rawCreated is String) {
      createdDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is int) {
      createdDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else if (rawCreated is DateTime) {
      createdDate = rawCreated;
    }

    return UserModel(
      uid: id,
      name: data['name'] ?? '',
      phoneNumber: data['phone_number'] ?? data['phoneNumber'] ?? data['phone'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'rider',
      rating: ((data['rating'] as num?) ?? 5.0).toDouble(),
      walletBalance: ((data['wallet_balance'] ?? data['walletBalance']) as num? ?? 0.0).toDouble(),
      createdAt: createdDate,
    );
  }

  Map<String, dynamic> toMap() {
    return toDatabaseMap();
  }

  /// Returns ONLY valid PostgreSQL column names for Supabase `users` table
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': uid,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'role': role,
      'rating': rating,
      'wallet_balance': walletBalance,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? name,
    String? phoneNumber,
    String? role,
    double? rating,
    double? walletBalance,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email,
      role: role ?? this.role,
      rating: rating ?? this.rating,
      walletBalance: walletBalance ?? this.walletBalance,
      createdAt: createdAt,
    );
  }
}
