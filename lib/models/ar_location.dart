import 'package:hive/hive.dart';

part 'ar_location.g.dart';

@HiveType(typeId: 0)
class ArLocation extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String subtitle;

  @HiveField(3)
  late String description;

  @HiveField(4)
  late double latitude;

  @HiveField(5)
  late double longitude;

  @HiveField(6)
  String? textMessage;

  @HiveField(7)
  String? imagePath;

  @HiveField(8)
  String? videoPath;

  @HiveField(9)
  String? modelPath;

  @HiveField(10)
  late String category;

  @HiveField(11)
  late DateTime createdDate;

  @HiveField(12)
  late DateTime updatedDate;

  @HiveField(13)
  String modelType;

  ArLocation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.textMessage,
    this.imagePath,
    this.videoPath,
    this.modelPath,
    required this.category,
    required this.createdDate,
    required this.updatedDate,
    this.modelType = 'default',
  });

  ArLocation copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    double? latitude,
    double? longitude,
    String? textMessage,
    String? imagePath,
    String? videoPath,
    String? modelPath,
    String? category,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? modelType,
  }) {
    return ArLocation(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      textMessage: textMessage ?? this.textMessage,
      imagePath: imagePath ?? this.imagePath,
      videoPath: videoPath ?? this.videoPath,
      modelPath: modelPath ?? this.modelPath,
      category: category ?? this.category,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      modelType: modelType ?? this.modelType,
    );
  }

  bool get hasText => textMessage != null && textMessage!.isNotEmpty;
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  bool get hasVideo => videoPath != null && videoPath!.isNotEmpty;
  bool get hasContent => hasText || hasImage || hasVideo;
}
