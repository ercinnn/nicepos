import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'product_columns_provider.g.dart';

enum ProductColumn {
  gorsel('Görsel'),
  barkod('Barkod'),
  stokKodu('Stok Kodu'),
  ustGrup('Üst Grup'),
  grupAdi('Grup Adı'),
  stok('Stok'),
  kritikStok('Kritik Stok'),
  birim('Birim'),
  kdv('KDV %'),
  alis('Alış Fiyatı'),
  fiyat1('Fiyat 1'),
  fiyat2('Fiyat 2');

  const ProductColumn(this.label);
  final String label;
}

const defaultProductColumns = {
  ProductColumn.barkod,
  ProductColumn.stok,
  ProductColumn.alis,
  ProductColumn.fiyat1,
};

@Riverpod(keepAlive: true)
class ProductColumns extends _$ProductColumns {
  @override
  Set<ProductColumn> build() => Set.from(defaultProductColumns);

  void toggle(ProductColumn col, bool visible) {
    state = visible ? {...state, col} : state.difference({col});
  }

  void reset() => state = Set.from(defaultProductColumns);
}
