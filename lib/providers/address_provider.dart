import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/address_controller.dart';
import '../models/address_model.dart';
import '../providers/auth_provider.dart';

// Provider for AddressController
final addressControllerProvider = Provider<AddressController>((ref) {
  return AddressController();
});

// Provider for all addresses
final addressesProvider = FutureProvider.autoDispose<List<AddressModel>>((ref) async {
  final authState = ref.watch(authUserProvider);
  final addressController = ref.watch(addressControllerProvider);
  
  return authState.when(
    data: (user) async {
      if (user != null) {
        return await addressController.getAddresses(user.uid);
      }
      return [];
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for a selected address to edit
final selectedAddressProvider = StateProvider<int?>((ref) => null);

// Provider for address loading state
final addressLoadingProvider = StateProvider<bool>((ref) => false);

// Provider for address error messages
final addressErrorProvider = StateProvider<String?>((ref) => null); 