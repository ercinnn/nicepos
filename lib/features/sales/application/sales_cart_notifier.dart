import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/models/cart_item.dart';
import '../data/repositories/sales_repository.dart';
import '../../../features/products/data/models/concept_product.dart';
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

/// Konsept Ürün'ü sepet satırlarına açar — her parça kendi Fiyat1'iyle ayrı
/// satır olur (stok/rapor/offline akışı tekil ürün satışıyla birebir aynı).
///  - Parça bazlı indirim (0069) tanımlıysa her satır KENDİ indirimini taşır
///    (%/₺); indirimsiz parça indirimsiz kalır.
///  - Hiç parça indirimi yoksa ESKİ konsept fiyatı (0067 `price`) geçerlidir:
///    fiyat < toplam → her satıra AYNI % iskonto; fiyat > toplam → birim
///    fiyatlar oranla ölçeklenir; parça toplamı 0 ise tutar ilk satıra yazılır.
/// Ürünü okunamayan parça (`product == null`) atlanır.
List<CartItem> conceptCartLines(ConceptProduct concept) {
  final parts = concept.items.where((i) => i.product != null).toList();
  if (parts.isEmpty) return const [];
  final sum = parts.fold<num>(0, (s, i) => s + i.product!.price1 * i.quantity);
  final price = concept.price;

  CartItem line(ConceptProductItem i,
      {num? unitPrice, num discountValue = 0, DiscountType discountType = DiscountType.percent}) {
    final p = i.product!;
    return CartItem(
      productId: p.id,
      productName: p.name,
      barcode: p.barcode,
      quantity: i.quantity,
      unitPrice: unitPrice ?? p.price1,
      discountValue: discountValue,
      discountType: discountType,
      conceptCode: concept.barcode,
    );
  }

  if (parts.any((i) => i.discountValue > 0)) {
    return [
      for (final i in parts)
        line(i, discountValue: i.discountValue, discountType: i.discountType),
    ];
  }
  if (price == null || price == sum) {
    return [for (final i in parts) line(i)];
  }
  if (sum <= 0) {
    return [
      for (var k = 0; k < parts.length; k++)
        line(parts[k], unitPrice: k == 0 ? price / parts[k].quantity : 0),
    ];
  }
  if (price < sum) {
    final pct = (sum - price) / sum * 100;
    return [for (final i in parts) line(i, discountValue: pct)];
  }
  final ratio = price / sum;
  return [for (final i in parts) line(i, unitPrice: i.product!.price1 * ratio)];
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
      // Konsept satırları (iskontolu olabilir) tekil okutmayla birleşmez.
      final index = items.indexWhere(
          (i) => i.productId == product.id && i.conceptCode == null);
      if (index >= 0) {
        items[index] = items[index].copyWith(quantity: items[index].quantity + 1);
      } else {
        items.add(CartItem(productId: product.id, productName: product.name, barcode: product.barcode, unitPrice: product.price1));
      }
      return tab.copyWith(items: items);
    });
  }

  /// Konsept barkodu okutulunca parçaları sepete ekler. Aynı konseptin
  /// satırı zaten varsa adedi artırılır: % iskonto adetle zaten orantılıdır,
  /// ₺ iskonto ise satır başına sabit olduğundan yeni satırınkiyle TOPLANIR
  /// (iki konsept = iki kat ₺ indirim).
  void addConcept(ConceptProduct concept) {
    final lines = conceptCartLines(concept);
    if (lines.isEmpty) return;
    _updateActive((tab) {
      final items = [...tab.items];
      for (final line in lines) {
        final index = items.indexWhere(
            (i) => i.productId == line.productId && i.conceptCode == line.conceptCode);
        if (index >= 0) {
          final existing = items[index];
          final addTl = existing.discountType == DiscountType.tl &&
              line.discountType == DiscountType.tl;
          items[index] = existing.copyWith(
            quantity: existing.quantity + line.quantity,
            discountValue: addTl ? existing.discountValue + line.discountValue : null,
          );
        } else {
          items.add(line);
        }
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

  // Sepet satırının birim fiyatını elle günceller — satır tutarı anında yenilenir
  // (design-tokens §5, KARAR v1.6). Kalıcı ürün fiyatı (products.price1) DEĞİL,
  // yalnızca bu satışın satır fiyatıdır; kalıcılık "Fiyat1 yap" ile ayrıca yapılır.
  void updateItemUnitPrice(int index, num unitPrice) {
    _updateActive((tab) {
      final items = [...tab.items];
      items[index] = items[index].copyWith(unitPrice: unitPrice);
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
