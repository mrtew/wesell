import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:go_router/go_router.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
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
  late GoogleMapsPlaces _places;
  
  // Constants
  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(4.1093195, 109.45547499999998),
    zoom: 10,
  );
  
  // Text controller for the search field
  final TextEditingController _searchController = TextEditingController();
  // List of search predictions
  List<Prediction> _predictions = [];
  // Flag to indicate if search is active
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initPlaces();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  // Initialize Places API
  Future<void> _initPlaces() async {
    try {
      final headers = await GoogleApiHeaders().getHeaders();
      _places = GoogleMapsPlaces(
        apiKey: 'AIzaSyBUXGLDsx8IBC2RnZVZyzolDunATmcCbWk',
        apiHeaders: headers,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize Places API: $e')),
        );
      }
    }
  }

  // Search for places using the Places API
  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() {
        _predictions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final PlacesAutocompleteResponse response = await _places.autocomplete(
        query,
        language: 'en',
        components: [Component(Component.country, "my")], // Restrict to Malaysia
      );

      if (response.status == 'OK') {
        setState(() {
          _predictions = response.predictions;
          _isSearching = false;
        });
      } else {
        _onError(response);
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during search: $e')),
      );
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _onError(PlacesAutocompleteResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: 'Message',
        message: response.errorMessage ?? 'An error occurred',
        contentType: ContentType.failure,
      ),
    ));
  }

  Future<void> _displayPrediction(Prediction prediction) async {
    // Close the search overlay
    setState(() {
      _predictions = [];
      _searchController.clear();
    });
    
    try {
      PlacesDetailsResponse detail = await _places.getDetailsByPlaceId(prediction.placeId!);
      
      if (detail.status == 'OK') {
        final lat = detail.result.geometry!.location.lat;
        final lng = detail.result.geometry!.location.lng;
        
        _markers.clear();
        final marker = Marker(
          markerId: const MarkerId('deliveryMarker'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: prediction.description ?? '',
          ),
        );
        
        setState(() {
          _markers['myLocation'] = marker;
          _controller?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: LatLng(lat, lng), zoom: 15),
            ),
          );
          _latitude = lat;
          _longitude = lng;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching place details: $e')),
      );
    }
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
          
          // // Search bar
          // Positioned(
          //   top: 10,
          //   left: 10,
          //   right: 10,
          //   child: Container(
          //     decoration: BoxDecoration(
          //       color: Colors.white,
          //       borderRadius: BorderRadius.circular(8),
          //       boxShadow: [
          //         BoxShadow(
          //           color: Colors.grey.withOpacity(0.5),
          //           spreadRadius: 2,
          //           blurRadius: 5,
          //           offset: const Offset(0, 2),
          //         ),
          //       ],
          //     ),
          //     child: TextField(
          //       controller: _searchController,
          //       decoration: InputDecoration(
          //         hintText: 'Search for a location',
          //         prefixIcon: const Icon(Icons.search),
          //         suffixIcon: _searchController.text.isNotEmpty
          //             ? IconButton(
          //                 icon: const Icon(Icons.clear),
          //                 onPressed: () {
          //                   _searchController.clear();
          //                   setState(() {
          //                     _predictions = [];
          //                   });
          //                 },
          //               )
          //             : null,
          //         border: InputBorder.none,
          //         contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          //       ),
          //       onChanged: (value) {
          //         _searchPlaces(value);
          //       },
          //     ),
          //   ),
          // ),
          
          // // Predictions list
          // if (_predictions.isNotEmpty)
          //   Positioned(
          //     top: 60,
          //     left: 10,
          //     right: 10,
          //     child: Container(
          //       decoration: BoxDecoration(
          //         color: Colors.white,
          //         borderRadius: BorderRadius.circular(8),
          //         boxShadow: [
          //           BoxShadow(
          //             color: Colors.grey.withOpacity(0.5),
          //             spreadRadius: 2,
          //             blurRadius: 5,
          //             offset: const Offset(0, 2),
          //           ),
          //         ],
          //       ),
          //       constraints: BoxConstraints(
          //         maxHeight: MediaQuery.of(context).size.height * 0.4,
          //       ),
          //       child: ListView.builder(
          //         shrinkWrap: true,
          //         itemCount: _predictions.length,
          //         itemBuilder: (context, index) {
          //           final prediction = _predictions[index];
          //           return ListTile(
          //             leading: const Icon(Icons.location_on),
          //             title: Text(
          //               prediction.structuredFormatting?.mainText ?? prediction.description ?? '',
          //               style: const TextStyle(fontWeight: FontWeight.bold),
          //             ),
          //             subtitle: Text(
          //               prediction.structuredFormatting?.secondaryText ?? '',
          //               overflow: TextOverflow.ellipsis,
          //             ),
          //             onTap: () {
          //               _displayPrediction(prediction);
          //             },
          //           );
          //         },
          //       ),
          //     ),
          //   ),
          
          // // Loading indicator
          // if (_isSearching)
          //   const Positioned(
          //     top: 60,
          //     right: 10,
          //     child: CircularProgressIndicator(),
          //   ),
          
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