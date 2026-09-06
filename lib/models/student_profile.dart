import 'package:uuid/uuid.dart';

class StudentProfile {
  final String id;
  String name;
  String avatarEmoji;
  int avatarColorValue;
  DateTime createdAt;

  StudentProfile({
    String? id,
    required this.name,
    this.avatarEmoji = '🎓',
    this.avatarColorValue = 0xFF2563EB,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarEmoji': avatarEmoji,
        'avatarColorValue': avatarColorValue,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Student',
      avatarEmoji: json['avatarEmoji'] as String? ?? '🎓',
      avatarColorValue: json['avatarColorValue'] as int? ?? 0xFF2563EB,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  StudentProfile copyWith({
    String? id,
    String? name,
    String? avatarEmoji,
    int? avatarColorValue,
    DateTime? createdAt,
  }) {
    return StudentProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
