import 'store_product.dart';

class CartItem {
  final StoreProduct product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  num get subtotal => product.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);
}
