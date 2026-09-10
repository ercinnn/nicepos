-- =============================================================================
-- 0062: Hatalı ŞEN ve DEMİREL firma kayıtlarını companies tablosundan sil
-- =============================================================================
-- 0060'ta eklenmişlerdi ama 0061 bunların aslında yanlış veri girişi olduğunu
-- (gerçek tedarikçi sırasıyla MİEN ve HOBBYLIFE) ortaya çıkardı — kullanıcı
-- bu iki hatalı kaydın silinmesini istedi.
--
-- `companies.name` üzerinde foreign key YOK (products.description salt
-- metin, companies.id'ye referans vermiyor) — bu silme products tablosunu
-- ETKİLEMEZ, yalnız Firmalar sekmesindeki autocomplete listesinden kaldırır.
--
-- Uygulama: anon key ile DELETE de RLS'ye takılır → Supabase SQL Editor'da
-- elle çalıştırılmalı.

delete from companies
where id in (
  'bd0efefb-46ec-48ac-b9cb-0b6b1e029660', -- ŞEN
  'd553883d-1c43-44a9-92ba-c16157f56031'  -- DEMİREL
)
returning id, name;
