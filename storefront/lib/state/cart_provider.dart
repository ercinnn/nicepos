import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/cart_item.dart';
import '../data/models/store_product.dart';
import '../data/store_repository.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) => StoreRepository());

// Sepet — yalnız bellekte tutulur (v1: sayfa yenilenince sıfırlanır, sunucu
// tarafında hiçbir şey yazılmaz — sipariş ancak checkout'ta create_online_order
// çağrılınca kalıcı olur).
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super(const []);

  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);

  num get total => state.fold(0, (sum, item) => sum + item.subtotal);

  void add(StoreProduct product, {int quantity = 1}) {
    final index = state.indexWhere((item) => item.product.id == product.id);
    if (index == -1) {
      state = [...state, CartItem(product: product, quantity: quantity)];
      return;
    }
    final updated = [...state];
    updated[index] = updated[index].copyWith(quantity: updated[index].quantity + quantity);
    state = updated;
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    state = [
      for (final item in state)
        if (item.product.id == productId) item.copyWith(quantity: quantity) else item,
    ];
  }

  void remove(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void clear() => state = const [];
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());
