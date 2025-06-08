import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location_pkg;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

import '../../widgets/app_bar_widget.dart';

class OpenMapScreen extends ConsumerStatefulWidget {
  const OpenMapScreen({super.key});

  @override
  ConsumerState<OpenMapScreen> createState() => _OpenMapScreenState();
}

class _OpenMapScreenState extends ConsumerState<OpenMapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final location_pkg.Location _location = location_pkg.Location();
  final Map<String, Marker> _markers = {};
  bool _isInitialLocationObtained = false;
  double _latitude = 4.1093195;
  double _longitude = 109.45547499999998;
  GoogleMapController? _controller;
  
  // Constants
  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(4.1093195, 109.45547499999998),
    zoom: 10,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    location_pkg.PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == location_pkg.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != location_pkg.PermissionStatus.granted) {
        return;
      }
    }

    location_pkg.LocationData currentPosition = await _location.getLocation();
    setState(() {
      _latitude = currentPosition.latitude!;
      _longitude = currentPosition.longitude!;
      final marker = Marker(
        markerId: const MarkerId('myLocation'),
        position: LatLng(_latitude, _longitude),
      );
      _markers['myLocation'] = marker;
      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(_latitude, _longitude), zoom: 15),
        ),
      );
      _isInitialLocationObtained = true;
    });
  }

  void _onConfirmButtonPressed() async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
        _latitude, _longitude,
      );

      if (placemarks.isNotEmpty) {
        geocoding.Placemark place = placemarks.first;
        String? city = place.locality ?? '';
        if (city == '') {
          city = place.subLocality ?? '';
        }
        if (city == '') {
          city = ' ';
        }
        
        String? postalCode = place.postalCode ?? '';
        if (postalCode == '') {
          postalCode = ' ';
        }
        
        String? state = place.administrativeArea ?? '';
        if (state == '') {
          state = ' ';
        }
        
        String? country = place.country ?? '';
        if (country == '') {
          country = ' ';
        }

        if (mounted) {
          GoRouter.of(context).push(
            '/add_address/$city/$postalCode/$state/$country/$_latitude/$_longitude',
          );
        }
      } else {
        if (mounted) {
          _showErrorDialog("No placemarks found for the selected location.");
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog("Error during geocoding: $e");
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Not valid location'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _latitude = position.target.latitude;
      _longitude = position.target.longitude;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: const AppBarWidget(
        title: 'Select Location',
        showBackButton: true,
      ),
      body: Stack(
        children: [
          // Map
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: GoogleMap(
              onCameraMove: _onCameraMove,
              mapType: MapType.normal,
              myLocationEnabled: true,
              initialCameraPosition: _initialPosition,
              markers: {
                Marker(
                  markerId: const MarkerId('user_location'),
                  position: LatLng(_latitude, _longitude),
                ),
              },
              onTap: (LatLng latlng) {
                setState(() {
                  _latitude = latlng.latitude;
                  _longitude = latlng.longitude;
                  final marker = Marker(
                    markerId: const MarkerId('myLocation'),
                    position: LatLng(_latitude, _longitude),
                  );
                  _markers['myLocation'] = marker;
                });
              },
              onMapCreated: (GoogleMapController controller) {
                _controller = controller;
              },
            ),
          ),
          
          // Confirm button
          Positioned(
            bottom: 40,
            left: 80,
            right: 80,
            child: ElevatedButton(
              onPressed: _isInitialLocationObtained ? _onConfirmButtonPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isInitialLocationObtained
                    ? const Color(0XFF20941C)
                    : Colors.grey,
              ),
              child: Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
} 