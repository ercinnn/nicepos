-- NicePOS - Satış silme: TEK atomik RPC ile (complete_sale/complete_sale_offline ile aynı desen)
--
-- Amaç: `SalesRepository.deleteSale()` şu adımları sıralı ayrı Supabase gidiş-
-- dönüşleriyle yapıyordu: sale_items oku (stok iadesi için) + HER kalem için ayrı
-- increment_product_stock RPC + customer_payments delete + kasa_reconciliations
-- delete + sale_items delete + sales delete. 1 kalemlik bir satışta bile bu 6
-- sıralı round-trip demekti (~2.5sn ölçüldü) — `complete_sale`'i yavaşlatan aynı
-- N+ ağ şelalesi. Şimdi hepsi TEK PL/pgSQL fonksiyon gövdesinde (tek transaction,
-- tek round-trip) yapılıyor.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.

create or replace function delete_sale(p_sale_id uuid) returns void as $$
declare
  item record;
begin
  if not exists (select 1 from sales where id = p_sale_id) then
    raise exception 'Satış bulunamadı.';
  end if;

  -- Stok iadesi: completeSale() satış anında decrementStock yapmıştı.
  for item in select product_id, quantity from sale_items where sale_id = p_sale_id
  loop
    if item.product_id is not null then
      update products
      set stock_quantity = stock_quantity + item.quantity,
          updated_at = now()
      where id = item.product_id;
    end if;
  end loop;

  -- Açık hesap borcunu geri alır (customer_balances bu hareketlerden hesaplanır).
  delete from customer_payments where sale_id = p_sale_id;

  -- Kasa mutabakat düzeltme satışıysa bağlı kaydı da sil (FK engeli + mutabakatsız hâle dönsün).
  delete from kasa_reconciliations where sale_id = p_sale_id;

  delete from sale_items where sale_id = p_sale_id;
  delete from sales where id = p_sale_id;
end;
$$ language plpgsql security definer;
