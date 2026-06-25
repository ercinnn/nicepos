-- sale_items.product_id FK'sini SET NULL olarak güncelle.
-- Böylece satış geçmişi olan bir ürün silinebilir;
-- product_id null olur ama product_name metni korunur.
alter table sale_items
  drop constraint sale_items_product_id_fkey,
  add constraint sale_items_product_id_fkey
    foreign key (product_id) references products(id) on delete set null;
