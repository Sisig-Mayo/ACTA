-- ============================================================
-- ACTA Migration 007 — Barangay GeoJSON RPC Function
-- ============================================================
-- Creates a PostgreSQL function that returns all barangay
-- polygons as a GeoJSON FeatureCollection for the Flutter map.
-- ============================================================

CREATE OR REPLACE FUNCTION get_barangays_geojson()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'type', 'FeatureCollection',
    'features', COALESCE(jsonb_agg(
      jsonb_build_object(
        'type', 'Feature',
        'properties', jsonb_build_object(
          'id', b.id,
          'barangay_name', b.barangay_name,
          'district', b.district
        ),
        'geometry', ST_AsGeoJSON(ST_SimplifyPreserveTopology(b.geom, 0.0005))::jsonb
      )
    ), '[]'::jsonb)
  )
  FROM barangays b
  WHERE b.geom IS NOT NULL;
$$;
