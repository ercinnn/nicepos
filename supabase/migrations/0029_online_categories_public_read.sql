-- NicePOS - Online Satış: storefront kategori navigasyonu
--
-- `product_groups` şu ana kadar yalnız staff'a (authenticated) açıktı
-- (0002_rls.sql). Storefront (anon) ürünleri kategoriye göre filtreleyebilmek
-- için grup adlarını okuyabilmeli. Grup adı/hiyerarşisi hassas veri değil
-- (fiyat/stok içermez) — bu yüzden mevcut "authenticated full access"
-- politikasına DOKUNMADAN, ek bir permissive SELECT politikası eklenir
-- (Postgres RLS'te aynı komut için birden çok permissive policy OR'lanır).
create policy "public read product_groups" on product_groups
  for select using (true);
