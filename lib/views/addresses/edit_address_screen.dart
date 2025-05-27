import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_bar_widget.dart';
// import '../../controllers/address_controller.dart';

class EditAddressScreen extends ConsumerStatefulWidget {
  const EditAddressScreen({super.key});

  @override
  ConsumerState<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends ConsumerState<EditAddressScreen> {
  late TextEditingController recipientNameController;
  late TextEditingController recipientPhoneController;
  late TextEditingController noteController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    recipientNameController = TextEditingController();
    recipientPhoneController = TextEditingController();
    noteController = TextEditingController();
  }

  @override
  void dispose() {
    recipientNameController.dispose();
    recipientPhoneController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedAddressIndex = ref.watch(selectedAddressProvider);
    
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'Edit Address',
        showBackButton: true,
      ),
      body: ref.watch(addressesProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (addresses) {
          if (selectedAddressIndex == null || selectedAddressIndex < 0 || selectedAddressIndex >= addresses.length) {
            // No valid address selected, show error
            return const Center(child: Text('No address selected for editing'));
          }

          final address = addresses[selectedAddressIndex];
          
          // Initialize controllers with address values if not set
          if (recipientNameController.text.isEmpty) {
            recipientNameController.text = address.recipientName ?? '';
          }
          if (recipientPhoneController.text.isEmpty) {
            recipientPhoneController.text = address.recipientPhone ?? '';
          }
          if (noteController.text.isEmpty) {
            noteController.text = address.note ?? '';
          }

          return SingleChildScrollView(
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
                        target: LatLng(address.latitude ?? 0, address.longitude ?? 0),
                        zoom: 16.0,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected_location'),
                          position: LatLng(address.latitude ?? 0, address.longitude ?? 0),
                        ),
                      },
                      zoomGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 32.0,
                          child: Center(
                            child: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: ListTile(
                            title: Text(
                              address.fullAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: recipientNameController,
                    decoration: InputDecoration(
                      labelText: 'Recipient Name*',
                      hintText: 'Your name ...',
                      helperText: 'e.g.: Alex',
                      hintStyle: const TextStyle(color: Colors.grey),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: recipientPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Recipient Phone*',
                      hintText: 'Your phone ...',
                      helperText: 'e.g.: +60123456789',
                      hintStyle: const TextStyle(color: Colors.grey),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      hintText: 'Any note',
                      helperText: 'e.g.: Home, Office',
                      hintStyle: const TextStyle(color: Colors.grey),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _updateAddress(address, selectedAddressIndex),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Save Address'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateAddress(dynamic address, int addressIndex) async {
    if (recipientNameController.text.isEmpty) {
      _showValidationError('Recipient Name is required field.');
      return;
    }

    if (recipientPhoneController.text.isEmpty) {
      _showValidationError('Recipient Phone is required field.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await ref.read(authUserProvider.future);
      if (user != null) {
        final addressController = ref.read(addressControllerProvider);
        final success = await addressController.editAddress(
          userId: user.uid,
          addressIndex: addressIndex,
          recipientName: recipientNameController.text,
          recipientPhone: recipientPhoneController.text,
          address: address.address ?? '',
          city: address.city ?? '',
          postalCode: address.postalCode ?? '',
          state: address.state ?? '',
          country: address.country ?? '',
          note: noteController.text,
          isDefault: address.isDefault ?? false,
          latitude: address.latitude ?? 0,
          longitude: address.longitude ?? 0,
        );

        if (mounted) {
          if (success) {
            _showSuccessDialog();
          } else {
            _showErrorDialog('Failed to update address. Please try again.');
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
          content: const Text('Address updated successfully.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Pop back to addresses screen
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
}