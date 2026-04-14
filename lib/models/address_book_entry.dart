

class AddressBookEntry {
  final String label;
  final String address;

  const AddressBookEntry({
    required this.label,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
      };

  factory AddressBookEntry.fromJson(Map<String, dynamic> json) {
    return AddressBookEntry(
      label: (json['label'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
    );
  }
}