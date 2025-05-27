import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_bar_widget.dart';
import '../../providers/address_provider.dart';
// import '../../providers/user_provider.dart';
// import '../../controllers/address_controller.dart';

class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  late Location location;
  int selectedAddressIndex = -1;

  @override
  void initState() {
    super.initState();
    location = Location();
    // Refresh the addresses when the screen loads
    Future.microtask(() => ref.refresh(addressesProvider));
    Future.microtask(() => ref.refresh(currentUserProvider));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(
        title: 'My Addresses',
        showBackButton: true,
      ),
      body: ref.watch(addressesProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (addresses) {
          if (addresses.isEmpty) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'My Addresses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 1,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 80),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 36,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No address',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      onTap: () {
                        _checkLocationPermissionAndNavigate();
                      },
                      child: const Text(
                        '+ Add New Address',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            selectedAddressIndex = addresses.indexWhere((address) => address.isDefault == true);
            if (selectedAddressIndex == -1 && addresses.isNotEmpty) {
              selectedAddressIndex = 0;
            }
            
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'My Addresses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 1,
                      color: Colors.grey,
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: addresses.length,
                      itemBuilder: (context, index) {
                        final address = addresses[index];
                        return Column(
                          children: [
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedAddressIndex = index;
                                });
                                _updateDefaultAddress(int.parse(address.id!));
                              },
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Radio(
                                  value: index,
                                  groupValue: selectedAddressIndex,
                                  onChanged: (int? value) {
                                    setState(() {
                                      selectedAddressIndex = value ?? -1;
                                    });
                                    _updateDefaultAddress(int.parse(address.id!));
                                  },
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${address.recipientName}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${address.recipientPhone}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ]
                                    ),
                                    Text(
                                      address.fullAddress,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (String result) {
                                    if (result == 'edit') {
                                      // Set selected address for editing
                                      ref.read(selectedAddressProvider.notifier).state = int.parse(address.id!);
                                      GoRouter.of(context).push('/edit_address');
                                    } else if (result == 'delete') {
                                      _deleteAddress(int.parse(address.id!));
                                    }
                                  },
                                  itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit),
                                        title: Text('Edit'),
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete),
                                        title: Text('Delete'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 1,
                              color: Colors.grey,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        },
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
              onPressed: () {
                _checkLocationPermissionAndNavigate();
              },
              child: const Text('+ Add New Address'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkLocationPermissionAndNavigate() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      await location.requestService();
      if (await location.serviceEnabled()) {
        if (mounted) {
          GoRouter.of(context).push('/open_map');
        }
      } else {
        _showLocationServiceDialog();
      }
    } else {
      _showLocationPermissionDeniedDialog();
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Service Disabled'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please enable location services to use this feature.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Denied'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please grant location permission to use this feature.'),
              SizedBox(height: 16),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _updateDefaultAddress(int addressIndex) async {
    final user = await ref.read(authUserProvider.future);
    if (user != null) {
      final addressController = ref.read(addressControllerProvider);
      await addressController.setDefaultAddress(user.uid, addressIndex);
      // Refresh addresses
      // ref.refresh(addressesProvider);
      Future.microtask(() => ref.refresh(addressesProvider));
    }
  }

  void _deleteAddress(int addressIndex) async {
    final user = await ref.read(authUserProvider.future);
    if (user != null) {
      final addressController = ref.read(addressControllerProvider);
      final success = await addressController.deleteAddress(user.uid, addressIndex);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address deleted successfully')),
          );
          // Refresh addresses
          // ref.refresh(addressesProvider);
          Future.microtask(() => ref.refresh(addressesProvider));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete address')),
          );
        }
      }
    }
  }
} 