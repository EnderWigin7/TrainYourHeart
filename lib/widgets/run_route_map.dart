import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';

/// A read-only route map. If [follow] is true, camera centers on the last
/// [points] entry as the list grows; otherwise it fits the full polyline once.
/// An optional [plannedRoute] is drawn underneath the live track as a dashed,
/// semi-transparent orange line.
class RunRouteMap extends StatefulWidget {
  final List<LatLng> points;
  final List<LatLng>? plannedRoute;
  final bool follow;
  const RunRouteMap({
    super.key,
    required this.points,
    this.plannedRoute,
    this.follow = false,
  });

  @override
  State<RunRouteMap> createState() => _RunRouteMapState();
}

class _RunRouteMapState extends State<RunRouteMap> {
  final MapController _controller = MapController();
  bool _fitted = false;

  @override
  void didUpdateWidget(covariant RunRouteMap old) {
    super.didUpdateWidget(old);
    if (widget.follow && widget.points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.move(widget.points.last, _controller.camera.zoom);
      });
    }
  }

  void _fitOnce() {
    if (_fitted) return;
    final all = <LatLng>[
      ...widget.points,
      ...?widget.plannedRoute,
    ];
    if (all.length < 2) return;
    _fitted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(all),
          padding: const EdgeInsets.all(24),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPoints = widget.points.isNotEmpty;
    final hasPlanned =
        widget.plannedRoute != null && widget.plannedRoute!.isNotEmpty;
    if (!hasPoints && !hasPlanned) {
      return Container(
        color: Colors.white.withValues(alpha: 0.04),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 36, color: AppColors.subtleGrey),
            SizedBox(height: 8),
            Text('Carte indisponible',
                style: TextStyle(color: AppColors.subtleGrey)),
          ],
        ),
      );
    }
    if (!widget.follow) _fitOnce();
    final initial = hasPoints
        ? widget.points.last
        : widget.plannedRoute!.first;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: initial,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.projectsynthese',
          tileProvider: NetworkTileProvider(),
        ),
        if (hasPlanned)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.plannedRoute!,
                strokeWidth: 4,
                color: AppColors.stravaOrange.withValues(alpha: 0.45),
                pattern: StrokePattern.dashed(segments: const [10, 8]),
              ),
            ],
          ),
        if (hasPoints)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.points,
                strokeWidth: 5,
                color: AppColors.stravaOrange,
              ),
            ],
          ),
        if (widget.follow && hasPoints)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.points.last,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.stravaOrange,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
