import 'dart:convert';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:excel/excel.dart' hide Border;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single vet clinic entry. [location] starts out null (it is not stored
/// in the spreadsheet) and gets filled in lazily by [VetClinicService.resolveLocations].
class VetClinicPin {
  final String id;
  final String name;
  final String address;
  final String postcode;
  final String district;
  final String state;
  final String phone;
  final String photoUrl;
  LatLng? location;

  VetClinicPin({
    required this.id,
    required this.name,
    required this.address,
    required this.postcode,
    required this.district,
    required this.state,
    required this.phone,
    required this.photoUrl,
    this.location,
  });

  factory VetClinicPin.fromMap(Map<String, dynamic> map) {
    return VetClinicPin(
      id: VetClinicService.idFor(map['name'] ?? '', map['address'] ?? ''),
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      postcode: map['postcode'] ?? '',
      district: map['district'] ?? '',
      state: map['state'] ?? 'All States',
      phone: map['phone'] ?? 'N/A',
      photoUrl: map['photoUrl'] ?? '',
    );
  }

  /// The clinic's own address, exactly as given in the directory - this is
  /// what gets geocoded, not the clinic name. Postcode is included because
  /// it's the single biggest accuracy boost for Malaysian addresses.
  String get geocodeQuery {
    String clean(String s) => s.replaceAll(RegExp(r',\s*$'), '').trim();
    final parts = [address, postcode, district, state, 'Malaysia']
        .map(clean)
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  /// Shape expected by ClinicDetailsPage / the VetClinicPage list cards, so
  /// the same detail screen can be reused from the map.
  Map<String, dynamic> toClinicData() {
    return {
      'name': name,
      'address': address,
      'state': state,
      'phone': phone,
      'photoUrl': photoUrl,
    };
  }
}

/// Loads the clinic directory from the bundled spreadsheet and resolves
/// clinic addresses to map coordinates, caching results on-device so the
/// rate-limited geocoding lookup only ever has to run once per clinic.
class VetClinicService {
  VetClinicService._();

  static const String _geoCachePrefix = 'vet_clinic_geo_';

  static const List<String> clinicPhotos = [
    'https://images.unsplash.com/photo-1586773860418-d37222d8fce3?w=500&q=80',
    'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=500&q=80',
    'https://images.unsplash.com/photo-1512678080530-7760d81faba6?w=500&q=80',
    'https://images.unsplash.com/photo-1538108149393-fbbd81895907?w=500&q=80',
    'https://images.unsplash.com/photo-1514416432279-50fac261c4dd?w=500&q=80',
    'https://images.unsplash.com/photo-1576091160550-2173ff3e52bf?w=500&q=80',
    'https://images.unsplash.com/photo-1581056771107-11a4208a0d9e?w=500&q=80',
    'https://images.unsplash.com/photo-1624727828456-0ba4637e77a2?w=500&q=80',
    'https://images.unsplash.com/photo-1584982751601-0571224f1661?w=500&q=80',
    'https://images.unsplash.com/photo-1516574187841-cb9cc2ca948b?w=500&q=80',
    'https://images.unsplash.com/photo-1497366216548-37526070297c?w=500&q=80',
    'https://images.unsplash.com/photo-1497366754045-fad886134a41?w=500&q=80',
    'https://images.unsplash.com/photo-1504328345606-18bbc8c9d7d1?w=500&q=80',
    'https://images.unsplash.com/photo-1551601651-2a8555f1a136?w=500&q=80',
    'https://images.unsplash.com/photo-1519494080410-f9aa76cb4283?w=500&q=80',
    'https://images.unsplash.com/photo-1504813184591-01572f98c85f?w=500&q=80',
    'https://images.unsplash.com/photo-1516549655169-df83a0774514?w=500&q=80',
    'https://images.unsplash.com/photo-1579684385127-1ef15d508118?w=500&q=80',
    'https://images.unsplash.com/photo-1629909613654-28e377c37b09?w=500&q=80',
    'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=500&q=80',
  ];

  static const List<String> malaysiaStates = [
    'All States',
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Perak',
    'Perlis',
    'Pulau Pinang',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'W.P. Kuala Lumpur',
    'W.P. Labuan',
    'W.P. Putrajaya',
  ];

  /// Stable id for a clinic derived from its name + address. Used both as a
  /// widget key and as the geocode cache key, so it must stay deterministic.
  static String idFor(String name, String address) =>
      '$name|$address'.hashCode.toString();

  static String guessStateFromAddress(String address) {
    final addr = address.toLowerCase();
    if (addr.contains('kuala lumpur') || addr.contains(' kl') || addr.contains('setapak')) return 'W.P. Kuala Lumpur';
    if (addr.contains('putrajaya')) return 'W.P. Putrajaya';
    if (addr.contains('labuan')) return 'W.P. Labuan';
    if (addr.contains('selangor') || addr.contains('petaling') || addr.contains('shah alam') || addr.contains('klang') || addr.contains('subang')) return 'Selangor';
    if (addr.contains('pulau pinang') || addr.contains('penang') || addr.contains('georgetown') || addr.contains('butterworth')) return 'Pulau Pinang';
    if (addr.contains('johor') || addr.contains(' jb') || addr.contains('skudai') || addr.contains('batu pahat')) return 'Johor';
    if (addr.contains('perak') || addr.contains('ipoh') || addr.contains('taiping')) return 'Perak';
    if (addr.contains('melaka') || addr.contains('malacca')) return 'Melaka';
    if (addr.contains('negeri sembilan') || addr.contains('seremban') || addr.contains('nilai')) return 'Negeri Sembilan';
    if (addr.contains('pahang') || addr.contains('kuantan')) return 'Pahang';
    if (addr.contains('kedah') || addr.contains('alor setar') || addr.contains('sungai petani')) return 'Kedah';
    if (addr.contains('kelantan') || addr.contains('kota bharu')) return 'Kelantan';
    if (addr.contains('terengganu') || addr.contains('kuala terengganu')) return 'Terengganu';
    if (addr.contains('perlis') || addr.contains('kangar')) return 'Perlis';
    if (addr.contains('sabah') || addr.contains('kota kinabalu')) return 'Sabah';
    if (addr.contains('sarawak') || addr.contains('kuching') || addr.contains('miri')) return 'Sarawak';
    return 'All States';
  }

  /// Parses the bundled klinik.xlsx into a flat list of clinic records.
  /// This is local/offline and cheap - safe to call every time the app opens.
  static Future<List<VetClinicPin>> loadClinics() async {
    final ByteData data = await rootBundle.load('assets/klinik.xlsx');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final excel = Excel.decodeBytes(bytes);
    final List<VetClinicPin> extracted = [];

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table]!;

      // The workbook can contain other sheets with a completely different
      // column layout (e.g. an unrelated hospital-license list) or empty
      // placeholder sheets. Only parse sheets that actually match the vet
      // clinic directory's header row - otherwise rows get misread into the
      // wrong fields and most of them (silently) get filtered out, which
      // looks like "only one clinic loaded" to the user.
      if (sheet.maxRows < 4) continue;
      final header = sheet.row(2);
      final isClinicSheet = header.length > 2 &&
          header[1]?.value?.toString().trim() == 'Bil' &&
          header[2]?.value?.toString().trim() == 'Nama Klinik';
      if (!isClinicSheet) continue;

      for (int i = 3; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.length < 8 || row[2] == null) continue;

        final name = row[2]?.value?.toString().trim() ?? '';
        if (name.isEmpty ||
            name.startsWith('*Nota') ||
            name.startsWith('T/B') ||
            name.toLowerCase() == 'nama klinik') {
          continue;
        }

        final address1 = row[3]?.value?.toString().trim() ?? '';
        final address2 = row[4]?.value?.toString().trim() ?? '';
        final postcode = row[5]?.value?.toString().trim() ?? '';
        final district = row[6]?.value?.toString().trim() ?? '';
        final rawState = row[7]?.value?.toString().trim() ?? '';
        final phone = row[8]?.value?.toString().trim() ?? 'N/A';
        final fullAddress = address2.isNotEmpty ? '$address1, $address2' : address1;
        final photoUrl = clinicPhotos[(i + name.length) % clinicPhotos.length];
        final state = guessStateFromAddress('$fullAddress $rawState');

        extracted.add(VetClinicPin.fromMap({
          'name': name,
          'address': fullAddress,
          'postcode': postcode,
          'district': district,
          'state': state,
          'phone': phone,
          'photoUrl': photoUrl,
        }));
      }
    }

    return extracted;
  }

  /// Resolves lat/lng for [clinics], using any cached value first and
  /// falling back to a Nominatim lookup for the rest.
  ///
  /// Nominatim's usage policy allows roughly one request per second, so
  /// lookups run sequentially with a short delay between them.
  /// [onEachResolved] fires after every clinic (cached or freshly geocoded)
  /// so the caller can add markers to the map incrementally instead of
  /// waiting for the whole batch to finish. Pass [shouldStop] so a caller
  /// can cancel a long-running batch (e.g. when the page is disposed or the
  /// user switches states).
  static Future<void> resolveLocations(
      List<VetClinicPin> clinics, {
        void Function(VetClinicPin pin)? onEachResolved,
        bool Function()? shouldStop,
      }) async {
    final prefs = await SharedPreferences.getInstance();

    for (final pin in clinics) {
      if (shouldStop != null && shouldStop()) return;
      if (pin.location != null) {
        onEachResolved?.call(pin);
        continue;
      }

      final cached = prefs.getString('$_geoCachePrefix${pin.id}');
      if (cached != null) {
        final parts = cached.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0]);
          final lng = double.tryParse(parts[1]);
          if (lat != null && lng != null) {
            pin.location = LatLng(lat, lng);
            onEachResolved?.call(pin);
            continue;
          }
        }
      }

      try {
        LatLng? found = await _geocode(pin.geocodeQuery);

        // Full street-level addresses sometimes don't match anything in
        // OpenStreetMap. Falling back to postcode + district + state still
        // lands the pin in the right neighbourhood rather than dropping it.
        if (found == null) {
          final fallbackParts = [pin.postcode, pin.district, pin.state, 'Malaysia']
              .map((s) => s.replaceAll(RegExp(r',\s*$'), '').trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (fallbackParts.isNotEmpty) {
            found = await _geocode(fallbackParts.join(', '));
          }
        }

        if (found != null) {
          pin.location = found;
          await prefs.setString(
              '$_geoCachePrefix${pin.id}', '${found.latitude},${found.longitude}');
          onEachResolved?.call(pin);
        }
      } catch (_) {
        // Skip clinics that fail to geocode; they simply won't get a pin.
      }

      // Respect Nominatim's fair-use rate limit before the next lookup.
      await Future.delayed(const Duration(milliseconds: 1100));
    }
  }

  static Future<LatLng?> _geocode(String query) async {
    final response = await http.get(
      Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      ),
      headers: {'User-Agent': 'PetHealthCareApp/1.0'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        final lat = double.tryParse(data[0]['lat'].toString());
        final lng = double.tryParse(data[0]['lon'].toString());
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    }
    return null;
  }
}