-- =============================================================================
-- 0048: Kiracı özel domain'i — tenants sütunları + store_tenants view güncellemesi
-- =============================================================================
-- `domain_purchases` (0047) satın alma denemesinin durumunu takip eder;
-- yalnız BAŞARIYLA `connected` olan bir deneme buraya yazılır. v1
-- basitleştirmesi: kiracı başına TEK aktif custom domain (unique sütun) —
-- geçmiş/başarısız denemeler domain_purchases'ta kalır, buraya sızmaz.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (add column if not exists / create or replace).
-- =============================================================================

alter table tenants add column if not exists custom_domain text unique;
alter table tenants add column if not exists custom_domain_status text
  not null default 'none' check (custom_domain_status in ('none', 'connected'));

-- store_tenants (0045/0046) — yeni sütun EN SONA eklenir (CREATE OR REPLACE
-- VIEW mevcut sütunları yeniden konumlandıramaz/adlandıramaz — CLAUDE.md'nin
-- "Diğer yaşanmış migration dersleri" notu).
create or replace view store_tenants as
select id, name, slug, storefront_image_aspect, custom_domain
from tenants
where is_active = true;

grant select on store_tenants to anon, authenticated;
