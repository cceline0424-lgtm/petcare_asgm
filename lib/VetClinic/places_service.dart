import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  // Fix: Remove "String.fromEnvironment" and just use regular quotes
  static const String _apiKey = 'AQ.Ab8RN6IP2DGHOEQ5herqqR-dEz18SLiad1QrzZDd1z18g_xnEg';

  static const String _searchUrl =
      'https://places.googleapis.com/v1/places:searchText';

  // ... the rest of your code remains exactly the same
  static Future<List<Map<String, dynamic>>> searchVeterinaryClinics({
    String searchText = '',
    String selectedArea = 'All Areas',
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Google Places API key is missing. '
            'Run the app with --dart-define=GOOGLE_PLACES_API_KEY=YOUR_KEY',
      );
    }

    String query;

    if (searchText.trim().isNotEmpty) {
      if (selectedArea == 'All Areas') {
        query = '$searchText veterinary clinic in Malaysia';
      } else {
        query = '$searchText veterinary clinic in $selectedArea, Malaysia';
      }
    } else {
      if (selectedArea == 'All Areas') {
        query = 'veterinary clinics in Malaysia';
      } else {
        query = 'veterinary clinics in $selectedArea, Malaysia';
      }
    }

    final response = await http.post(
      Uri.parse(_searchUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
        'places.id,places.displayName,places.formattedAddress,places.photos',
      },
      body: jsonEncode({
        'textQuery': query,
        'languageCode': 'en',
        'regionCode': 'MY',
        'maxResultCount': 20,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load clinics.\n'
            'Status Code: ${response.statusCode}\n'
            'Response: ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    final List places = data['places'] ?? [];

    return places.map<Map<String, dynamic>>((place) {
      final List photos = place['photos'] ?? [];

      String? photoName;

      if (photos.isNotEmpty) {
        photoName = photos.first['name'];
      }

      return {
        'placeId': place['id'] ?? '',
        'name': place['displayName']?['text'] ?? 'Unknown Clinic',
        'address': place['formattedAddress'] ?? 'Address unavailable',
        'area': selectedArea,
        'photoName': photoName,
      };
    }).toList();
  }

  /// Convert the Google Place Photo resource name into an image URL.
  static String? getPhotoUrl(String? photoName) {
    if (photoName == null || photoName.isEmpty) {
      return null;
    }

    return 'https://places.googleapis.com/v1/'
        '$photoName/media'
        '?maxWidthPx=800'
        '&key=$_apiKey';
  }
}