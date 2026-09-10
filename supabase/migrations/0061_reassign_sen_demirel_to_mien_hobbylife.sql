-- =============================================================================
-- 0061: ŞEN(KARDEŞLER) → MİEN, DEMİREL → HOBBYLIFE yeniden ataması
-- =============================================================================
-- 0058'de "ŞEN" ve "DEMİREL"i ayrı (kayıtsız) firma sanıp öyle normalize
-- etmiştik — kullanıcı bunların aslında YANLIŞ/hatalı veri girişi olduğunu,
-- gerçek tedarikçinin sırasıyla MİEN ve HOBBYLIFE (ikisi de zaten `companies`
-- tablosunda kayıtlı) olduğunu belirtti. Bu migration description'ı buna
-- göre düzeltir.
--
-- "ŞEN"in yanı sıra "ŞEN KARDEŞLER"/"SENKARDESLER" gibi (0058'den önce hiç
-- görülmemiş, muhtemelen henüz normalize edilmemiş) varyantlar da hedeflenir
-- — Türkçe-aksan sadeleştirilip hem tek başına "sen" hem "sen kardesler"/
-- "senkardesler" biçimleri yakalanır.
--
-- Uygulama: anon key ile UPDATE de RLS'ye takılır (yalnız `authenticated`
-- blanket-erişim politikası) → Supabase SQL Editor'da elle çalıştırılmalı.

-- ŞEN / ŞEN KARDEŞLER / SENKARDESLER → MİEN
update products
set description = 'MİEN'
where lower(translate(description, 'çÇğĞıİöÖşŞüÜ', 'cCgGiIoOsSuU')) = 'sen'
   or description ~* 'sen ?kardesler'
   or description ~* 'senkardesler'
returning id, name, description;

-- DEMİREL → HOBBYLIFE
update products
set description = 'HOBBYLIFE'
where description ~* 'demirel'
returning id, name, description;
