import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_bar_widget.dart';
// import '../../controllers/address_controller.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  final String? city;
  final String? postalCode;
  final String? state_;
  final String? country;
  final double? latitude;
  final double? longitude;

  const AddAddressScreen({
    super.key,
    required this.city,
    required this.postalCode,
    required this.state_,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  late TextEditingController recipientNameController;
  late TextEditingController recipientPhoneController;
  late TextEditingController addressController;
  late TextEditingController noteController;
  late TextEditingController cityController;
  late TextEditingController postalCodeController;
  late TextEditingController stateController;
  late TextEditingController countryController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    recipientNameController = TextEditingController();
    recipientPhoneController = TextEditingController();
    addressController = TextEditingController();
    noteController = TextEditingController();
    cityController = TextEditingController(text: widget.city ?? '');
    postalCodeController = TextEditingController(text: widget.postalCode ?? '');
    stateController = TextEditingController(text: widget.state_ ?? '');
    countryController = TextEditingController(text: widget.country ?? '');
  }

  @override
  void dispose() {
    recipientNameController.dispose();
    recipientPhoneController.dispose();
    addressController.dispose();
    noteController.dispose();
    cityController.dispose();
    postalCodeController.dispose();
    stateController.dispose();
    countryController.dispose();
    super.dispose();
  }

  void _validateAndSave() async {
    if (recipientNameController.text.isEmpty && recipientPhoneController.text.isEmpty && addressController.text.isEmpty) {
      _showValidationError('Recipient Name, Recipient Phone and Address are required fields.');
    } else if (recipientNameController.text.isEmpty) {
      _showValidationError('Recipient Name is required field.');
    } else if (recipientPhoneController.text.isEmpty) {
      _showValidationError('Recipient Phone is required field.');
    } else if (addressController.text.isEmpty) {
      _showValidationError('Address is required field.');
    } else {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = await ref.read(authUserProvider.future);
        if (user != null) {
          final addressController = ref.read(addressControllerProvider);
          final success = await addressController.addAddress(
            userId: user.uid,
            recipientName: recipientNameController.text,
            recipientPhone: recipientPhoneController.text,
            address: this.addressController.text,
            city: cityController.text,
            postalCode: postalCodeController.text,
            state: stateController.text,
            country: countryController.text,
            note: noteController.text,
            latitude: widget.latitude!,
            longitude: widget.longitude!,
          );

          if (mounted) {
            if (success) {
              _showSuccessDialog();
            } else {
              _showErrorDialog('Failed to add address. Please try again.');
            }
          }
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Error: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showValidationError(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Validation Error'),
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Address added successfully.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Pop back to addresses screen
                GoRouter.of(context).pop();
                GoRouter.of(context).pop();
                // Refresh the addresses list
                Future.microtask(() => ref.refresh(addressesProvider));
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Add Address',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Information Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 1,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(widget.latitude!, widget.longitude!),
                    zoom: 16.0,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: LatLng(widget.latitude!, widget.longitude!),
                    ),
                  },
                  zoomGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                "Recipient Name*", 
                recipientNameController,
                'Your name ...', 
                'e.g.: Alex'
              ),
              const SizedBox(height: 24),
              _buildTextField(
                "Recipient Phone*", 
                recipientPhoneController,
                'Your phone ...', 
                'e.g.: +60123456789'
              ),
              const SizedBox(height: 24),
              _buildTextField(
                "Address*", 
                addressController,
                'Your address ...', 
                'e.g.: unit, block, street'
              ),
              const SizedBox(height: 24),
              _buildFixedTextField("City", cityController, widget.city),
              const SizedBox(height: 24),
              _buildFixedTextField("Postal Code", postalCodeController, widget.postalCode),
              const SizedBox(height: 24),
              _buildFixedTextField("State", stateController, widget.state_),
              const SizedBox(height: 24),
              _buildFixedTextField("Country", countryController, widget.country),
              const SizedBox(height: 24),
              _buildTextField(
                "Note (Optional)",
                noteController,
                'Any note ...',
                'e.g.: Home, Office'
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.grey,
              width: 1.0,
            ),
          ),
        ),
        child: BottomAppBar(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _validateAndSave,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Save Address'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? hintText,
    String? helperText
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        hintText: hintText ?? '',
        hintStyle: const TextStyle(color: Colors.grey),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildFixedTextField(
    String label,
    TextEditingController controller,
    String? initialValue
  ) {
    controller.text = initialValue ?? '';
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabled: false,
      ),
    );
  }
}