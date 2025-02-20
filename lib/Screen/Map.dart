import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  // final LatLng _gayatriNagar = const LatLng(26.8850, 75.7726);
  final LatLng _manasarovarPlaza = const LatLng(26.8715, 75.7938);
  Set<Polyline> _polylines = {};

  // Add these variables in _MapPageState
  final String _apiKey = 'AIzaSyC6FQL6N44IwDliONfmjbtmzwUD8OQjBwk';

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
      location.onLocationChanged.listen((loc.LocationData locationData) async {
        if (mounted && _isTracking) {
          final currentLatLng = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );

          setState(() {
            currentLocation = locationData;
            _userMarker = Marker(
              markerId: const MarkerId('user'),
              position: currentLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: const InfoWindow(title: 'Your Location'),
              rotation: locationData.heading ?? 0.0,
              flat: true,
            );
          });

          // Clear existing polylines
          _polylines.clear();

          // Draw routes to both destinations
          // await _getDirectionsAndDraw(
          //   currentLatLng, 
          //   _gayatriNagar, 
          //   'route_gayatri',
          //   Colors.blue
          // );
          
          await _getDirectionsAndDraw(
            currentLatLng, 
            _manasarovarPlaza, 
            'route_manasarovar',
            Colors.red
          );

          // Update camera
          mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: currentLatLng,
                zoom: 15.0,
                bearing: locationData.heading ?? 0.0,
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
          //  _gayatriNagar,
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
        // Marker(
        //   markerId: const MarkerId('gayatri'),
       //   position: _gayatriNagar,
        //   icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        //   infoWindow: const InfoWindow(
        //     title: 'Gayatri Nagar',
        //     snippet: 'Destination 1',
        //   ),
        // ), 
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

  // Add this method to get route from Google Directions API
  Future<void> _getDirectionsAndDraw(LatLng origin, LatLng destination, String routeId, Color color) async {
    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          final points = data['routes'][0]['overview_polyline']['points'];
          final List<LatLng> routePoints = _decodePolyline(points);
          
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: PolylineId(routeId),
                points: routePoints,
                color: color,
                width: 5,
              ),
            );
          });
        }
      }
    } catch (e) {
      print('Error getting directions: $e');
    }
  }

  // Add polyline decoder method
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

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
