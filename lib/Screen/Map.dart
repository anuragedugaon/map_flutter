import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;
  loc.Location location = loc.Location();
  loc.LocationData? currentLocation;
  bool _isTracking = false;
  bool _locationPermissionGranted = false;

  // Durga Mandir and nearby locations
  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('durga_mandir'),
      position: LatLng(25.6082, 85.1362),
      infoWindow: InfoWindow(
        title: 'Durga Mandir', //
        snippet: 'Famous Temple',
      ),
    ),
    const Marker(
      markerId: MarkerId('gayatri_nagar'),
      position: LatLng(25.6123, 85.1401),
      infoWindow: InfoWindow(
        title: 'Gayatri Nagar',
        snippet: 'Residential Area',
      ),
    ),
    // Add more locations here
  };

  Marker? _userMarker;

  // Update these variables at the top of _MapPageState
  final LatLng _gayatriNagar = const LatLng(26.8850, 75.7726);
  final LatLng _manasarovarPlaza = const LatLng(26.8715, 75.7938);
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    // Check location permission
    var status = await Permission.location.status;
    if (status.isGranted) {
      setState(() => _locationPermissionGranted = true);
      _initLocationService();
    } else {
      _requestLocationPermission();
    }
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      setState(() => _locationPermissionGranted = true);
      _initLocationService();
    } else {
      // Show dialog if permission denied
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'This app needs location permission to show your position on the map. Please grant location permission in settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _initLocationService() async {
    try {
      // Request location permission first
      var permissionStatus = await Permission.location.request();
      if (!permissionStatus.isGranted) {
        return;
      }

      // Enable location service
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      // Start location updates with high accuracy
      location.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        interval: 1000, // Update every second
        distanceFilter: 5, // Update if moved 5 meters
      );

      // Listen to location updates
      location.onLocationChanged.listen((loc.LocationData locationData) {
        if (mounted && _isTracking) {
          final currentLatLng = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );

          setState(() {
            currentLocation = locationData;

            // Update user marker
            _userMarker = Marker(
              markerId: const MarkerId('user'),
              position: currentLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
              infoWindow: const InfoWindow(
                title: 'Your Location',
                snippet: 'You are here',
              ),
              rotation: locationData.heading ?? 0.0,
              flat: true,
            );

            // Update polylines with new location
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: [
                  currentLatLng,
                  _gayatriNagar,
                  _manasarovarPlaza,
                  currentLatLng,
                ],
                color: Colors.blue,
                width: 4,
                patterns: [
                  PatternItem.dash(20),
                  PatternItem.gap(10),
                ],
              ),
            );
          });

          // Smoothly follow user location
          mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: currentLatLng,
                zoom: 16.0,
                bearing: locationData.heading ?? 0.0,
                tilt: 45.0,
              ),
            ),
          );
        }
      });

      // Get initial location
      currentLocation = await location.getLocation();
      if (currentLocation != null) {
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                currentLocation!.latitude!,
                currentLocation!.longitude!,
              ),
              zoom: 18.0,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error initializing location: $e");
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Location Error'),
            content: Text('Please enable location services and try again.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _initLocationService(); // Try again
                },
                child: Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Update the _createPolylines method
  void _createPolylines(LatLng currentLocation) {
    setState(() {
      _polylines.clear();

      // Triangle between all locations
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('location_triangle'),
          points: [
            currentLocation,
            _gayatriNagar,
            _manasarovarPlaza,
            currentLocation, // Complete the loop
          ],
          color: Colors.blue,
          width: 4,
          patterns: [
            PatternItem.dash(20),
            PatternItem.gap(10),
          ],
        ),
      );

      // Update markers
      _markers.clear();
      _markers.addAll({
        Marker(
          markerId: const MarkerId('current'),
          position: currentLocation,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
        ),
        Marker(
          markerId: const MarkerId('gayatri'),
          position: _gayatriNagar,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Gayatri Nagar',
            snippet: 'Destination 1',
          ),
        ),
        Marker(
          markerId: const MarkerId('manasarovar'),
          position: _manasarovarPlaza,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: const InfoWindow(
            title: 'Manasarovar Plaza',
            snippet: 'Destination 3',
          ),
        ),
      });
    });
  }

  // Future<void> _createUserIcon() async {
  //   _userIcon = await BitmapDescriptor.fromAssetImage(
  //     ImageConfiguration(size: Size(48, 48)),
  //     'assets/image/image.png',
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TEST MAP',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(
              _isTracking ? Icons.location_on : Icons.location_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isTracking = !_isTracking;
              });
            },
          ),
        ],
      ),
      body: !_locationPermissionGranted
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Location permission is required',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _requestLocationPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target:
                        const LatLng(25.6082, 85.1362), // Durga Mandir location
                    zoom: 14,
                  ),
                  polylines: _polylines,
                  markers: {
                    ..._markers,
                    if (_userMarker != null) _userMarker!,
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapType: MapType.normal,
                  compassEnabled: true,
                ),
                if (_isTracking)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'Live Tracking is on',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
