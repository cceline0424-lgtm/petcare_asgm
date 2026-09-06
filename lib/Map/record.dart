import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class StrayAnimalRecord {
  final String id;
  final LatLng location;
  String imageUrl;
  bool isRescued;

  String condition;
  String activityLog;
  String medicalActions;

  StrayAnimalRecord({
    required this.id,
    required this.location,
    required this.imageUrl,
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
      'imageUrl': imageUrl,
      'isRescued': isRescued,
      'condition': condition,
      'activityLog': activityLog,
      'medicalActions': medicalActions,
    };
  }

  factory StrayAnimalRecord.fromJson(Map<String, dynamic> json) {
    return StrayAnimalRecord(
      id: json['id'],
      location: LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()),
      imageUrl: json['imageUrl'] ?? json['imagePath'] ?? '',
      isRescued: json['isRescued'] ?? false,
      condition: json['condition'] ?? '',
      activityLog: json['activityLog'] ?? '',
      medicalActions: json['medicalActions'] ?? '',
    );
  }

  ImageProvider? get imageProvider {
    if (imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('data:image')) {
      final base64Part = imageUrl.substring(imageUrl.indexOf(',') + 1);
      try {
        return MemoryImage(base64Decode(base64Part));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(imageUrl);
  }
}