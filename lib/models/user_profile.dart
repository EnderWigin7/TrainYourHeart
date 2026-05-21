class UserProfile {
  final String username;
  final String email;
  final String passwordHash;
  final String passwordSalt;
  final double weightKg;
  final int age;
  final double dailyGoalKm;
  final String? photoPath;

  const UserProfile({
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    required this.weightKg,
    required this.age,
    required this.dailyGoalKm,
    this.photoPath,
  });

  UserProfile copyWith({
    String? username,
    String? email,
    String? passwordHash,
    String? passwordSalt,
    double? weightKg,
    int? age,
    double? dailyGoalKm,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return UserProfile(
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      dailyGoalKm: dailyGoalKm ?? this.dailyGoalKm,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'weightKg': weightKg,
        'age': age,
        'dailyGoalKm': dailyGoalKm,
        'photoPath': photoPath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        passwordHash: json['passwordHash'] as String? ?? '',
        passwordSalt: json['passwordSalt'] as String? ?? '',
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70,
        age: (json['age'] as num?)?.toInt() ?? 25,
        dailyGoalKm: (json['dailyGoalKm'] as num?)?.toDouble() ?? 3.0,
        photoPath: json['photoPath'] as String?,
      );

  static const empty = UserProfile(
    username: '',
    email: '',
    passwordHash: '',
    passwordSalt: '',
    weightKg: 70,
    age: 25,
    dailyGoalKm: 3.0,
  );
}
