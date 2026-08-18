import 'package:flutter/material.dart';

import '../../core/theme/guardian_tokens.dart';

/// FS-001 — LO-012 map surface. A dependency-free stylized map widget: no
/// external map SDK, no tile downloads, zero extra internet consumption.
/// Coordinates are projected with equirectangular math inside the card, so
/// every point, geofence circle, and route trace is drawn from real local
/// data. When no data exists the widget shows an honest empty state instead
/// of an empty canvas.
class GuardianMapWidget extends StatelessWidget {
  const GuardianMapWidget({
    super.key,
    this.points = const [],
    this.geofences = const [],
    this.memberIds = const {},
    this.routePoints = const [],
    this.showGrid = true,
    this.onTapPosition,
    this.emptyTitle,
    this.emptySubtitle,
    this.height = 220,
  });

  /// Latest location points drawn as member pins.
  final List<MapPoint> points;

  /// Geofence circles drawn on top of the pins.
  final List<MapGeofence> geofences;

  /// Optional highlight set of member ids; empty means show everything.
  final Set<String> memberIds;

  /// A route trace (location history) drawn as a polyline.
  final List<MapPoint> routePoints;

  final bool showGrid;

  /// Fires with normalized (0..1) canvas coordinates — used by the geofence
  /// creation flow to pick a center from the card tap.
  final void Function(double normalizedX, double normalizedY)? onTapPosition;

  final String? emptyTitle;
  final String? emptySubtitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasContent = points.isNotEmpty || geofences.isNotEmpty || routePoints.isNotEmpty;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1B3A6B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, size) {
            final hasTapTarget = onTapPosition != null;
            return hasContent
                ? GestureDetector(
                    onTapUp: hasTapTarget
                        ? (details) {
                            final box = details.localPosition;
                            onTapPosition!(
                                box.dx / size.maxWidth,
                                box.dy / size.maxHeight);
                          }
                        : null,
                    child: CustomPaint(
                      painter: _GuardianMapPainter(
                          points: points,
                          geofences: geofences,
                          memberIds: memberIds,
                          routePoints: routePoints,
                          showGrid: showGrid),
                      child: const SizedBox.expand(),
                    ),
                  )
                : _MapEmptyState(title: emptyTitle, subtitle: emptySubtitle);
          },
        ),
      ),
    );
  }
}

class MapPoint {
  const MapPoint({
    required this.latitude,
    required this.longitude,
    this.memberId,
    this.memberName,
    this.fresh = true,
  });
  final double latitude;
  final double longitude;
  final String? memberId;
  final String? memberName;
  final bool fresh;
}

class MapGeofence {
  const MapGeofence({
    required this.latitude,
    required this.longitude,
    required this.radiusFraction,
    this.name,
    this.status = 'active',
  });
  final double latitude;
  final double longitude;
  /// Radius as a fraction of the card width (precomputed from meters and
  /// the visible bounding box) — keeps the painter dependency-free.
  final double radiusFraction;
  final String? name;
  final String status;
}

class _GuardianMapPainter extends CustomPainter {
  _GuardianMapPainter({
    required this.points,
    required this.geofences,
    required this.memberIds,
    required this.routePoints,
    required this.showGrid,
  });

  final List<MapPoint> points;
  final List<MapGeofence> geofences;
  final Set<String> memberIds;
  final List<MapPoint> routePoints;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    if (showGrid) _paintGrid(canvas, size);
    _paintGeofences(canvas, size);
    _paintRoute(canvas, size);
    _paintPins(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF16335E));
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintGeofences(Canvas canvas, Size size) {
    for (final geofence in geofences) {
      final center = _project(geofence.longitude, geofence.latitude, size);
      final radius = geofence.radiusFraction * size.width;
      final entered = geofence.status == 'entered';
      final circle = Paint()
        ..color = entered
            ? GuardianTokens.guardianTeal.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, circle);
      final stroke = Paint()
        ..color = entered ? GuardianTokens.guardianTeal : Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, stroke);
    }
  }

  void _paintRoute(Canvas canvas, Size size) {
    if (routePoints.length < 2) return;
    final projected =
        routePoints.map((p) => _project(p.longitude, p.latitude, size)).toList();
    final paint = Paint()
      ..color = GuardianTokens.guardianTeal.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(projected.first.dx, projected.first.dy);
    for (var i = 1; i < projected.length; i++) {
      path.lineTo(projected[i].dx, projected[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintPins(Canvas canvas, Size size) {
    for (final point in points) {
      if (memberIds.isNotEmpty &&
          point.memberId != null &&
          !memberIds.contains(point.memberId)) {
        continue;
      }
      final center = _project(point.longitude, point.latitude, size);
      final pin = Paint()
        ..color = point.fresh ? GuardianTokens.guardianTeal : const Color(0xFFE8A33D)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 10, pin);
      final core = Paint()..color = Colors.white;
      canvas.drawCircle(center, 4, core);
      final pulse = Paint()
        ..color = point.fresh
            ? GuardianTokens.guardianTeal.withValues(alpha: 0.35)
            : const Color(0xFFE8A33D).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, 18, pulse);
      if (point.memberName != null) {
        final text = TextPainter(
            text: TextSpan(
                text: point.memberName,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
            textDirection: TextDirection.ltr)
          ..layout();
        text.paint(canvas, Offset(center.dx - text.width / 2, center.dy + 24));
      }
    }
  }

  Offset _project(double longitude, double latitude, Size size) {
    if (points.isEmpty) {
      return Offset(size.width / 2, size.height / 2);
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLon = p.longitude < minLon ? p.longitude : minLon;
      maxLon = p.longitude > maxLon ? p.longitude : maxLon;
    }
    final latSpan = (maxLat - minLat).abs() + 0.001;
    final lonSpan = (maxLon - minLon).abs() + 0.001;
    final x = ((longitude - minLon) / lonSpan) * (size.width - 24) + 12;
    final y = size.height - (((latitude - minLat) / latSpan) * (size.height - 24) + 12);
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _GuardianMapPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.geofences != geofences ||
      oldDelegate.routePoints != routePoints;
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({this.title, this.subtitle});

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF16335E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined,
                  color: Colors.white54, size: 36),
              const SizedBox(height: 10),
              Text(title ?? 'No map data',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!,
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
