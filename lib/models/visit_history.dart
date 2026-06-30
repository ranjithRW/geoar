import 'package:hive/hive.dart';

part 'visit_history.g.dart';

@HiveType(typeId: 1)
class VisitHistory extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String locationId;

  @HiveField(2)
  late String locationTitle;

  @HiveField(3)
  late DateTime visitTime;

  @HiveField(4)
  late int viewCount;

  @HiveField(5)
  late int clickCount;

  @HiveField(6)
  late int durationSeconds;

  @HiveField(7)
  double? latitude;

  @HiveField(8)
  double? longitude;

  VisitHistory({
    required this.id,
    required this.locationId,
    required this.locationTitle,
    required this.visitTime,
    this.viewCount = 1,
    this.clickCount = 0,
    this.durationSeconds = 0,
    this.latitude,
    this.longitude,
  });

  String get formattedDuration {
    if (durationSeconds < 60) return '${durationSeconds}s';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
