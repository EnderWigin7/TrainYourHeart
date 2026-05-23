import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/routing_service.dart';
import '../services/units_service.dart';
import '../theme.dart';
import 'run_screen.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final MapController _map = MapController();
  final _routing = RoutingService();
  final _firestore = FirestoreService();
  LatLng? _start;
  LatLng? _end;
  RoutingResult? _route;
  bool _loadingRoute = false;
  bool _initializingLocation = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _initializingLocation = false;
          _locationError = 'Service de localisation désactivé';
        });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _initializingLocation = false;
          _locationError = 'Autorisation localisation refusée';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _start = LatLng(pos.latitude, pos.longitude);
        _initializingLocation = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(_start!, 15);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializingLocation = false;
        _locationError = 'Erreur GPS: $e';
      });
    }
  }

  Future<void> _onTap(LatLng dest) async {
    if (_start == null) return;
    setState(() {
      _end = dest;
      _loadingRoute = true;
      _route = null;
    });
    final result = await _routing.foot(_start!, dest);
    if (!mounted) return;
    setState(() {
      _route = result;
      _loadingRoute = false;
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Itinéraire indisponible')),
      );
    }
  }

  Future<void> _launchRun() async {
    final profile = await _firestore.loadProfile() ?? UserProfile.empty;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RunScreen(
          weightKg: profile.weightKg,
          plannedRoute: _route?.points,
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    if (m < 60) return '${m}min';
    return '${d.inHours}h ${(m % 60).toString().padLeft(2, '0')}min';
  }

  @override
  Widget build(BuildContext context) {
    final units = UnitsService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('PLANIFIER UN ITINÉRAIRE')),
      body: _initializingLocation
          ? const Center(child: CircularProgressIndicator())
          : _start == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _locationError ??
                          'Position introuvable, réessayez plus tard.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.subtleGrey),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: _start!,
                          initialZoom: 15,
                          onTap: (_, latLng) => _onTap(latLng),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.projectsynthese',
                            tileProvider: NetworkTileProvider(),
                          ),
                          if (_route != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _route!.points,
                                  strokeWidth: 5,
                                  color: AppColors.stravaOrange,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _start!,
                                width: 18,
                                height: 18,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: AppColors.stravaOrange,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                              if (_end != null)
                                Marker(
                                  point: _end!,
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.topCenter,
                                  child: const Icon(
                                    Icons.place,
                                    color: AppColors.stravaOrange,
                                    size: 36,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_loadingRoute)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(),
                              )
                            else if (_route != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Column(
                                      children: [
                                        const Text(
                                          'DISTANCE',
                                          style: TextStyle(
                                            color: AppColors.subtleGrey,
                                            fontSize: 10,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        Text(
                                          units.formatDistance(
                                              _route!.distanceKm),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        const Text(
                                          'DURÉE EST.',
                                          style: TextStyle(
                                            color: AppColors.subtleGrey,
                                            fontSize: 10,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        Text(
                                          _fmtDuration(_route!.duration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Touchez la carte pour choisir une destination.',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: AppColors.subtleGrey),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _route != null ? _launchRun : null,
                                child: const Text('LANCER LA COURSE'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
