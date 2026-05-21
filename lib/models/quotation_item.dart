class QuotationItem {
  final String id;
  final String name;
  final String quantity;
  final String brand;
  final String model;
  final String notes;
  final String imageUrl;

  const QuotationItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.brand,
    required this.model,
    required this.notes,
    required this.imageUrl,
  });

  factory QuotationItem.fromMap(Map<String, dynamic> data) {
    final name = (data['name'] ?? data['product'] ?? '').toString().trim();
    final quantity = (data['quantity'] ?? '').toString().trim();
    final model = (data['model'] ?? '').toString().trim();

    return QuotationItem(
      id: (data['id'] ?? _fallbackId(name, quantity, model)).toString(),
      name: name,
      quantity: quantity,
      brand: (data['brand'] ?? '').toString().trim(),
      model: model,
      notes: (data['notes'] ?? '').toString().trim(),
      imageUrl: (data['imageUrl'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'brand': brand,
      'model': model,
      'notes': notes,
      'imageUrl': imageUrl,
    };
  }

  bool get hasImage => imageUrl.isNotEmpty;

  String get brandModelLabel {
    final parts = [brand, model].where((value) => value.trim().isNotEmpty);
    return parts.join(' • ');
  }

  static String _fallbackId(String name, String quantity, String model) {
    final raw = [
      name,
      quantity,
      model,
    ].where((value) => value.trim().isNotEmpty).join('-').toLowerCase();

    final sanitized = raw.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return sanitized.isEmpty ? 'item' : sanitized;
  }
}
