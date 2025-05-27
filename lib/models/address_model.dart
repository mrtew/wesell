import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String? id;
  final String? recipientName;
  final String? recipientPhone;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? state;
  final String? country;
  final String? note;
  final bool? isDefault;
  final double? latitude;
  final double? longitude;
  final Timestamp? createdAt;

  AddressModel({
    this.id,
    this.recipientName,
    this.recipientPhone,
    this.address,
    this.city,
    this.postalCode,
    this.state,
    this.country,
    this.note,
    this.isDefault,
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  factory AddressModel.fromMap(Map<String, dynamic> map, String id) {
    // Handle boolean conversion for isDefault
    bool? isDefaultValue;
    if (map['isDefault'] is bool) {
      isDefaultValue = map['isDefault'];
    } else if (map['isDefault'] is String) {
      isDefaultValue = (map['isDefault'] == 'true');
    } else {
      isDefaultValue = false;
    }

    // Handle Timestamp conversion for createdAt
    Timestamp? createdAtValue;
    if (map['createdAt'] is Timestamp) {
      createdAtValue = map['createdAt'];
    } else {
      createdAtValue = Timestamp.now();
    }

    // Handle numeric conversion for latitude and longitude
    double? latitudeValue;
    if (map['latitude'] is double) {
      latitudeValue = map['latitude'];
    } else if (map['latitude'] is String) {
      latitudeValue = double.tryParse(map['latitude']);
    }

    double? longitudeValue;
    if (map['longitude'] is double) {
      longitudeValue = map['longitude'];
    } else if (map['longitude'] is String) {
      longitudeValue = double.tryParse(map['longitude']);
    }

    return AddressModel(
      id: id,
      recipientName: map['recipientName'],
      recipientPhone: map['recipientPhone'],
      address: map['address'],
      city: map['city'],
      postalCode: map['postalCode'],
      state: map['state'],
      country: map['country'],
      note: map['note'],
      isDefault: isDefaultValue,
      latitude: latitudeValue,
      longitude: longitudeValue,
      createdAt: createdAtValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'state': state,
      'country': country,
      'note': note ?? '',
      'isDefault': isDefault ?? false,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt ?? Timestamp.now(),
    };
  }

  String get fullAddress {
    return '$address, $city, $postalCode, $state, $country';
  }
} 