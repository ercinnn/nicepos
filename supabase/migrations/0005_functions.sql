-- NicePOS - yardımcı fonksiyonlar

-- Satış tamamlandığında ürün stoğunu düşürür.
create or replace function decrement_product_stock(p_product_id uuid, p_quantity numeric)
returns void as $$
begin
  update products
  set stock_quantity = stock_quantity - p_quantity,
      updated_at = now()
  where id = p_product_id;
end;
$$ language plpgsql security definer;
