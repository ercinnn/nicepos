-- =============================================================================
-- 0043: Storage bucket'larının kiracı-bazlı izolasyonu — Faz E / Adım 1
-- =============================================================================
-- Önkoşul: 0036-0042 (tenants/memberships + current_tenant_id()) VE mevcut
-- dosyaların `<tenant_id>/...` önekiyle yeniden konumlandırılmış olması —
-- bu ADIM ELLE (Storage API üzerinden, SQL ile YAPILAMAZ — `storage.objects`
-- satırını doğrudan UPDATE etmek metadata'yı gerçek nesne baytlarından
-- ayrıştırır) tamamlandı: `product-images/products/*.ext` ve
-- `etiket_pdfleri/*` kökündeki TÜM dosyalar `<ilk-kiracının-id'si>/...`
-- altına copy+delete ile taşındı (move endpoint'i UPDATE RLS'i gerektirdiği
-- için 400 döndürdü — copy+delete select+insert+delete ile çalışır).
--
-- Sorun: `product-images`/`etiket_pdfleri` bucket'larının yazma politikaları
-- hâlâ `auth.role() = 'authenticated'` idi (0003/0014) — kiracı ayrımı YOKTU.
-- Çok kiracılı bir dünyada bu, herhangi bir kiracının başka bir kiracının
-- dosya adını bilirse/tahmin ederse onu okuyup (etiket_pdfleri: private,
-- authenticated ise herkese açık listelemeyle zaten görünür) üzerine
-- yazabileceği/silebileceği anlamına gelir. Çözüm: her yazma/okuma
-- politikası, path'in İLK segmentinin (`storage.foldername(name))[1]`)
-- `current_tenant_id()`'e eşit olmasını zorunlu kılar.
--
-- `product-images` SELECT (herkese açık okuma) BİLİNÇLİ OLARAK DOKUNULMAZ —
-- storefront ürün görsellerini herkese göstermesi gerekiyor (bkz.
-- online_products), bu tasarım gereği tenant-agnostic kalır; yalnız
-- YAZMA (insert/update/delete) kiracı-bazlı kısıtlanır.
--
-- Dart tarafı (bu migration'la birlikte deploy edilir): `ProductRepository.
-- uploadImage()` ve `LabelsStorageRepository`'nin tüm metodları artık path'i
-- `<tenant_id>/...` öneki ile oluşturuyor (bkz. lib/core/supabase/
-- tenant_context.dart, product_repository.dart, labels_storage_repository.dart).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- =============================================================================

-- ─── product-images: yazma kiracı-bazlı, okuma herkese açık kalır ───────────
drop policy if exists "Authenticated upload product images" on storage.objects;
drop policy if exists "Authenticated update product images" on storage.objects;
drop policy if exists "Authenticated delete product images" on storage.objects;

create policy "Tenant scoped upload product images"
  on storage.objects for insert
  with check (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

create policy "Tenant scoped update product images"
  on storage.objects for update
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

create policy "Tenant scoped delete product images"
  on storage.objects for delete
  using (
    bucket_id = 'product-images'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

-- ─── etiket_pdfleri: private bucket, okuma da kiracı-bazlı ──────────────────
drop policy if exists "Authenticated read etiket pdf" on storage.objects;
drop policy if exists "Authenticated upload etiket pdf" on storage.objects;
drop policy if exists "Authenticated delete etiket pdf" on storage.objects;

create policy "Tenant scoped read etiket pdf"
  on storage.objects for select
  using (
    bucket_id = 'etiket_pdfleri'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

create policy "Tenant scoped upload etiket pdf"
  on storage.objects for insert
  with check (
    bucket_id = 'etiket_pdfleri'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );

create policy "Tenant scoped delete etiket pdf"
  on storage.objects for delete
  using (
    bucket_id = 'etiket_pdfleri'
    and (storage.foldername(name))[1] = current_tenant_id()::text
  );
