-- =============================================================================
-- 0046: Storefront ürün görseli en-boy oranı — kiracı-bazlı tercih
-- =============================================================================
-- Kullanıcı isteği: Online Satış panelinden mağaza sahibi ürün kartlarının
-- görselini "Kare" (1:1) veya "Dikey Dikdörtgen" (3:4, mevcut varsayılan)
-- olarak seçebilsin. Site-geneli bir marka/görünüm kararı olduğundan
-- `update_tenant_name` (0042) ile AYNI desen: owner/admin'e özel RPC,
-- `tenants` tablosuna doğrudan UPDATE RLS'i YOK (SECURITY DEFINER RPC
-- kendi rol kontrolünü yapar).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (add column if not exists / create or replace).
-- =============================================================================

alter table tenants
  add column if not exists storefront_image_aspect text
  not null default 'portrait'
  check (storefront_image_aspect in ('square', 'portrait'));

create or replace function update_storefront_image_aspect(p_aspect text)
returns tenants as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_tenant tenants;
begin
  select tenant_id, role into v_tenant_id, v_role
  from memberships where user_id = auth.uid() limit 1;

  if v_tenant_id is null then
    raise exception 'Kiracı bulunamadı.';
  end if;
  if v_role not in ('owner', 'admin') then
    raise exception 'Bu işlem için yetkiniz yok.';
  end if;
  if p_aspect not in ('square', 'portrait') then
    raise exception 'Geçersiz görsel formatı.';
  end if;

  update tenants set storefront_image_aspect = p_aspect where id = v_tenant_id
  returning * into v_tenant;

  return v_tenant;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function update_storefront_image_aspect(text) to authenticated;

-- store_tenants (0045) — storefront'un okuduğu public view'a yeni sütun
-- EN SONA eklenir (CREATE OR REPLACE VIEW mevcut sütunları yeniden
-- adlandıramaz/pozisyonlayamaz, yalnız sona ekleme güvenlidir).
create or replace view store_tenants as
select id, name, slug, storefront_image_aspect
from tenants
where is_active = true;

grant select on store_tenants to anon, authenticated;
