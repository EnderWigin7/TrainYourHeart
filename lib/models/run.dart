class KmSplit {
  final int km;
  final Duration duration;
  const KmSplit({required this.km, required this.duration});

  double get paceMinPerKm => duration.inMilliseconds / 60000.0;

  Map<String, dynamic> toJson() => {
        'km': km,
        'ms': duration.inMilliseconds,
      };

  factory KmSplit.fromJson(Map<String, dynamic> json) => KmSplit(
        km: (json['km'] as num).toInt(),
        duration: Duration(milliseconds: (json['ms'] as num).toInt()),
      );
}

class Run {
  final String id;
  final DateTime startTime;
  final Duration duration;
  final double distanceMeters;
  final double caloriesBurned;
  final double averageSpeedKmh;
  final List<KmSplit> splits;
  final String? note;
  final int? difficulty;

  Run({
    required this.id,
    required this.startTime,
    required this.duration,
    required this.distanceMeters,
    required this.caloriesBurned,
    required this.averageSpeedKmh,
    this.splits = const [],
    this.note,
    this.difficulty,
  });

  double get distanceKm => distanceMeters / 1000.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'durationSeconds': duration.inSeconds,
        'distanceMeters': distanceMeters,
        'caloriesBurned': caloriesBurned,
        'averageSpeedKmh': averageSpeedKmh,
        'splits': splits.map((s) => s.toJson()).toList(),
        'note': note,
        'difficulty': difficulty,
      };

  factory Run.fromJson(Map<String, dynamic> json) => Run(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        duration: Duration(seconds: json['durationSeconds'] as int),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        caloriesBurned: (json['caloriesBurned'] as num).toDouble(),
        averageSpeedKmh: (json['averageSpeedKmh'] as num).toDouble(),
        splits: (json['splits'] as List?)
                ?.map((e) => KmSplit.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        note: json['note'] as String?,
        difficulty: (json['difficulty'] as num?)?.toInt(),
      );
}
