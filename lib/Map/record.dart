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

  /// Resolves [imageUrl] to something Flutter can actually paint.
  ///
  /// Stray pins are shared across every user viewing the map, so the photo
  /// has to live somewhere everyone can read it - it's stored as a
  /// Base64-encoded `data:image/...` string right inside the Firestore
  /// document (no Firebase Storage/billing needed). This also still
  /// understands the old `https://firebasestorage...` URLs from pins that
  /// were created before this change, so existing pins don't break.
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