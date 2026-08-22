import 'dart:io';
import 'package:latlong2/latlong.dart';

class StrayAnimalRecord {
  final String id;
  final LatLng location;
  File imageFile;
  bool isRescued;

  String condition;
  String activityLog;
  String medicalActions;

  StrayAnimalRecord({
    required this.id,
    required this.location,
    required this.imageFile,
    this.isRescued = false,
    this.condition = '',
    this.activityLog = '',
    this.medicalActions = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': location.latitude,
      'lng': location.longitude,
      'imagePath': imageFile.path,
      'isRescued': isRescued,
      'condition': condition,
      'activityLog': activityLog,
      'medicalActions': medicalActions,
    };
  }

  factory StrayAnimalRecord.fromJson(Map<String, dynamic> json) {
    return StrayAnimalRecord(
      id: json['id'],
      location: LatLng(json['lat'], json['lng']),
      imageFile: File(json['imagePath']),
      isRescued: json['isRescued'] ?? false,
      condition: json['condition'] ?? '',
      activityLog: json['activityLog'] ?? '',
      medicalActions: json['medicalActions'] ?? '',
    );
  }
}