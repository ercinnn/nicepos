-- =============================================================================
-- 0045: Storefront çoklu-kiracı — mağaza dizini (Faz F, Adım 1: alt alan
-- adı/slug ile kiracı çözümleme)
-- =============================================================================
-- `online_products`/`product_groups` zaten tenant_id taşıyor (0040/0037) ama
-- storefront (anon) bunu hiç kullanmıyordu — tek dağıtım tüm kiracıların
-- online-aktif ürünlerini karışık gösteriyordu (v1'de tek kiracı olduğundan
-- görünmeyen bir sorun). Bu migration storefront'un "hangi kiracıyım"
-- sorusunu cevaplayabilmesi için minimal bir public dizin ekler — anon
-- `tenants` tablosunu okuyamaz (current_tenant_id() üyeliğe bağlı), bu yüzden
-- ayrı, dar bir view gerekir. Asıl filtreleme istemci tarafında
-- (StoreRepository .eq('tenant_id', ...)) yapılır — online_products/
-- product_groups'un kendisi zaten tenant_id sütununu dışa veriyor.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (create or replace).
-- =============================================================================

create or replace view store_tenants as
select id, name, slug
from tenants
where is_active = true;

grant select on store_tenants to anon, authenticated;
