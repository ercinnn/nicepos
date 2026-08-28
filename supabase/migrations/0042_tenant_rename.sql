-- =============================================================================
-- 0042: Kiracı adını değiştirme — Faz C / Adım 1 (yalnız isim, logo/renk hariç)
-- =============================================================================
-- Önkoşul: 0036-0041 (tenants/memberships + current_tenant_id()).
--
-- Faz C'nin kapsamı: uygulama içi "NicePOS" hardcoded metninin kiracı adına
-- dönmesi (bkz. Dart tarafı: auth_provider.dart `currentTenantProvider`,
-- app_scaffold.dart). Bu migration yalnız owner/admin'in KENDİ kiracısının
-- adını değiştirebildiği atomik RPC'yi ekler — logo/renk white-label bilinçli
-- olarak Faz E (storage kiracı-izolasyonu) ile birlikte ele alınacak (bkz.
-- migration yorumu: mevcut Etiket logo yükleme mekanizması `__store_logo.txt`
-- hâlâ tenant-prefix'siz, üzerine şimdi genel marka logosu eklemek çapraz-
-- kiracı üzerine yazma riski taşır).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- =============================================================================

create or replace function update_tenant_name(p_name text)
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
  if trim(p_name) = '' then
    raise exception 'İşletme adı boş olamaz.';
  end if;

  update tenants set name = trim(p_name) where id = v_tenant_id
  returning * into v_tenant;

  return v_tenant;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function update_tenant_name(text) to authenticated;
