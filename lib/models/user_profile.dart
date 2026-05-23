class UserProfile {
  final String username;
  final String email;
  final double weightKg;
  final int age;
  final double dailyGoalKm;
  final double weeklyGoalKm;
  final double monthlyGoalKm;
  final String? photoPath;

  const UserProfile({
    required this.username,
    required this.email,
    required this.weightKg,
    required this.age,
    required this.dailyGoalKm,
    this.weeklyGoalKm = 20,
    this.monthlyGoalKm = 80,
    this.photoPath,
  });

  UserProfile copyWith({
    String? username,
    String? email,
    double? weightKg,
    int? age,
    double? dailyGoalKm,
    double? weeklyGoalKm,
    double? monthlyGoalKm,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return UserProfile(
      username: username ?? this.username,
      email: email ?? this.email,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      dailyGoalKm: dailyGoalKm ?? this.dailyGoalKm,
      weeklyGoalKm: weeklyGoalKm ?? this.weeklyGoalKm,
      monthlyGoalKm: monthlyGoalKm ?? this.monthlyGoalKm,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'weightKg': weightKg,
        'age': age,
        'dailyGoalKm': dailyGoalKm,
        'weeklyGoalKm': weeklyGoalKm,
        'monthlyGoalKm': monthlyGoalKm,
        'photoPath': photoPath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70,
        age: (json['age'] as num?)?.toInt() ?? 25,
        dailyGoalKm: (json['dailyGoalKm'] as num?)?.toDouble() ?? 3.0,
        weeklyGoalKm: (json['weeklyGoalKm'] as num?)?.toDouble() ?? 20,
        monthlyGoalKm: (json['monthlyGoalKm'] as num?)?.toDouble() ?? 80,
        photoPath: json['photoPath'] as String?,
      );

  static const empty = UserProfile(
    username: '',
    email: '',
    weightKg: 70,
    age: 25,
    dailyGoalKm: 3.0,
    weeklyGoalKm: 20,
    monthlyGoalKm: 80,
  );
}
