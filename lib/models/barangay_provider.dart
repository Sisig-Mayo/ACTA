/// ACTA Frontend — Barangay GeoJSON Provider
/// =============================================
/// Fetches barangay polygon data from the backend API
/// and parses it into flutter_map Polygon objects.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// -----------------------------------------------------------
// Data Model
// -----------------------------------------------------------

class BarangayPolygon {
  final int id;
  final String name;
  final String district;
  final List<List<LatLng>> rings; // outer ring + holes

  const BarangayPolygon({
    required this.id,
    required this.name,
    required this.district,
    required this.rings,
  });
}

// -----------------------------------------------------------
// Provider — Cached fetch of all barangay polygons
// -----------------------------------------------------------

final barangayPolygonsProvider =
    FutureProvider<List<BarangayPolygon>>((ref) async {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://acta-production.up.railway.app',
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 30),
  ));

  try {
    final response = await dio.get('/api/v1/barangays/geojson');
    if (response.statusCode != 200 || response.data == null) {
      return [];
    }

    final geojson = response.data as Map<String, dynamic>;
    final features = geojson['features'] as List<dynamic>? ?? [];

    final polygons = <BarangayPolygon>[];

    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>? ?? {};
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) continue;

      final geoType = geometry['type'] as String? ?? '';
      final coords = geometry['coordinates'];
      if (coords == null) continue;

      final id = props['id'] as int? ?? 0;
      final name = props['barangay_name'] as String? ?? 'Unknown';
      final district = props['district'] as String? ?? 'Unknown';

      List<List<LatLng>> rings = [];

      if (geoType == 'Polygon') {
        rings = _parsePolygonCoords(coords as List);
      } else if (geoType == 'MultiPolygon') {
        // Take the first polygon from the MultiPolygon for rendering
        for (final polygon in coords as List) {
          rings = _parsePolygonCoords(polygon as List);
          break; // Use first polygon
        }
      }

      if (rings.isNotEmpty) {
        polygons.add(BarangayPolygon(
          id: id,
          name: name,
          district: district,
          rings: rings,
        ));
      }
    }

    return polygons;
  } catch (e) {
    debugPrint('Failed to fetch barangay polygons: $e');
    return [];
  }
});

List<List<LatLng>> _parsePolygonCoords(List coords) {
  final rings = <List<LatLng>>[];
  for (final ring in coords) {
    final points = <LatLng>[];
    for (final coord in ring as List) {
      final c = coord as List;
      final lng = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      points.add(LatLng(lat, lng));
    }
    if (points.isNotEmpty) {
      rings.add(points);
    }
  }
  return rings;
}

// -----------------------------------------------------------
// Helper — Build flutter_map Polygons with risk coloring
// -----------------------------------------------------------

/// Builds a list of flutter_map Polygon widgets from barangay data.
/// If [riskMap] is provided (barangay_name -> zone_status), polygons
/// are colored RED/YELLOW/GREEN accordingly. Otherwise, all are
/// rendered with a default color.
List<Polygon> buildBarangayMapPolygons(
  List<BarangayPolygon> barangays, {
  Map<String, String>? riskMap,
}) {
  return barangays.map((b) {
    Color fillColor;
    Color borderColor;

    if (riskMap != null && riskMap.containsKey(b.name)) {
      final zone = riskMap[b.name]!.toUpperCase();
      switch (zone) {
        case 'RED':
          fillColor = const Color(0x771E3A8A);
          borderColor = const Color(0xFF1E3A8A);
          break;
        case 'YELLOW':
          fillColor = const Color(0x772563EB);
          borderColor = const Color(0xFF2563EB);
          break;
        default:
          fillColor = const Color(0x440EA5E9);
          borderColor = const Color(0xFF0EA5E9);
      }
    } else {
      // Default: semi-transparent outline
      fillColor = const Color(0x220EA5E9);
      borderColor = const Color(0xFF0EA5E9);
    }

    return Polygon(
      points: b.rings.first, // Outer ring
      color: fillColor,
      borderColor: borderColor,
      borderStrokeWidth: 1.0,
      isFilled: true,
    );
  }).toList();
}
