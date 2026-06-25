import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/cart_item.dart';
import '../data/repositories/sales_repository.dart';
import '../../../features/products/data/models/product.dart';

export '../data/models/cart_item.dart' show DiscountType;

part 'sales_cart_notifier.g.dart';

class CustomerTabState {
  final List<CartItem> items;
  final num discountValue;      // % veya TL — discountType'a göre yorumlanır
  final DiscountType discountType;
  final String? customerId;
  final String? customerName;

  const CustomerTabState({
    this.items = const [],
    this.discountValue = 0,
    this.discountType = DiscountType.percent,
    this.customerId,
    this.customerName,
  });

  num get subtotal => items.fold<num>(0, (sum, i) => sum + i.total);

  num get discountAmount => discountType == DiscountType.percent
      ? subtotal * discountValue / 100
      : discountValue.clamp(0, subtotal);

  // DB'ye her zaman yüzde olarak kaydedilir
  num get discountPercent =>
      subtotal > 0 ? (discountAmount / subtotal * 100) : 0;

  num get total => subtotal - discountAmount;

  CustomerTabState copyWith({
    List<CartItem>? items,
    num? discountValue,
    DiscountType? discountType,
    String? customerId,
    String? customerName,
    bool clearCustomer = false,
  }) {
    return CustomerTabState(
      items: items ?? this.items,
      discountValue: discountValue ?? this.discountValue,
      discountType: discountType ?? this.discountType,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
    );
  }
}

class SalesState {
  final int activeTab;
  final List<CustomerTabState> tabs;
  final bool isReturnMode;

  const SalesState({
    required this.activeTab,
    required this.tabs,
    this.isReturnMode = false,
  });

  factory SalesState.initial() =>
      SalesState(activeTab: 0, tabs: List.generate(5, (_) => const CustomerTabState()));

  CustomerTabState get active => tabs[activeTab];
}

@Riverpod(keepAlive: true)
SalesRepository salesRepository(SalesRepositoryRef ref) => SalesRepository();

@Riverpod(keepAlive: true)
class SalesCart extends _$SalesCart {
  @override
  SalesState build() => SalesState.initial();

  void _updateActive(CustomerTabState Function(CustomerTabState) update) {
    final tabs = [...state.tabs];
    tabs[state.activeTab] = update(tabs[state.activeTab]);
    state = SalesState(activeTab: state.activeTab, tabs: tabs, isReturnMode: state.isReturnMode);
  }

  void selectTab(int index) {
    state = SalesState(activeTab: index, tabs: state.tabs, isReturnMode: state.isReturnMode);
  }

  void toggleReturnMode() {
    state = SalesState(activeTab: state.activeTab, tabs: state.tabs, isReturnMode: !state.isReturnMode);
  }

  void addProduct(Product product) {
    _updateActive((tab) {
      final items = [...tab.items];
      final index = items.indexWhere((i) => i.productId == product.id);
      if (index >= 0) {
        items[index] = items[index].copyWith(quantity: items[index].quantity + 1);
      } else {
        items.add(CartItem(productId: product.id, productName: product.name, barcode: product.barcode, unitPrice: product.price1));
      }
      return tab.copyWith(items: items);
    });
  }

  void addMiscItem(num amount, {String? note}) {
    _updateActive((tab) {
      final items = [
        ...tab.items,
        CartItem(
          productName: (note != null && note.trim().isNotEmpty) ? note.trim() : 'Muhtelif Tutar',
          unitPrice: amount,
        ),
      ];
      return tab.copyWith(items: items);
    });
  }

  void updateItemQuantity(int index, num quantity) {
    _updateActive((tab) {
      final items = [...tab.items];
      if (quantity <= 0) {
        items.removeAt(index);
      } else {
        items[index] = items[index].copyWith(quantity: quantity);
      }
      return tab.copyWith(items: items);
    });
  }

  void updateItemDiscount(int index, num discount, DiscountType type) {
    _updateActive((tab) {
      final items = [...tab.items];
      items[index] = items[index].copyWith(discountValue: discount, discountType: type);
      return tab.copyWith(items: items);
    });
  }

  void updateItemNote(int index, String note) {
    _updateActive((tab) {
      final items = [...tab.items];
      items[index] = items[index].copyWith(note: note);
      return tab.copyWith(items: items);
    });
  }

  void removeItem(int index) {
    _updateActive((tab) {
      final items = [...tab.items]..removeAt(index);
      return tab.copyWith(items: items);
    });
  }

  void setDiscount(num value, DiscountType type) {
    _updateActive((tab) => tab.copyWith(discountValue: value, discountType: type));
  }

  void setDiscountType(DiscountType type) {
    _updateActive((tab) => tab.copyWith(discountType: type, discountValue: 0));
  }

  void setCustomer(String id, String name) {
    _updateActive((tab) => tab.copyWith(customerId: id, customerName: name));
  }

  void clearCustomer() {
    _updateActive((tab) => tab.copyWith(clearCustomer: true));
  }

  void clearActiveTab() {
    _updateActive((_) => const CustomerTabState());
  }
}
