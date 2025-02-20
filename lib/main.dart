import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'Screen/Map.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Test App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapPage(),
    );
  }
}

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  final Location _location = Location();
  Marker? _bikeMarker;
  bool _isFirstTime = true;
  BitmapDescriptor? _bikeIcon;

  @override
  void initState() {
    super.initState();
    _initBikeMarker();
    _startLocationUpdates();
  }

  Future<void> _initBikeMarker() async {
    final ByteData bytes = await rootBundle.load('assets/image/mony.jpg');
    final Uint8List list = bytes.buffer.asUint8List();
    _bikeIcon = BitmapDescriptor.fromBytes(list);
  }

  void _startLocationUpdates() {
    _location.onLocationChanged.listen((LocationData currentLocation) {
      if (!mounted) return;

      final LatLng position = LatLng(
        currentLocation.latitude!,
        currentLocation.longitude!,
      );

      setState(() {
        _bikeMarker = Marker(
          markerId: const MarkerId('bike'),
          position: position,
          rotation: currentLocation.heading ?? 0,
          icon: _bikeIcon ?? BitmapDescriptor.defaultMarker,
        );
      });

      if (_isFirstTime) {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: position,
              zoom: 17,
            ),
          ),
        );
        _isFirstTime = false;
      } else {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(position),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_bikeMarker != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(_bikeMarker!.position),
                );
              }
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(0, 0),
          zoom: 15,
        ),
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
        markers: _bikeMarker != null ? {_bikeMarker!} : {},
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        compassEnabled: true,
        mapType: MapType.normal,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
