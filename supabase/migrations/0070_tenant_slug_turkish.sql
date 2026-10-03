-- =============================================================================
-- 0070: ensure_tenant_bootstrap — slug üretiminde Türkçe harf dönüşümü
-- =============================================================================
-- YAŞANMIŞ HATA: 0041'deki slug üretimi `regexp_replace(ad, '[^a-zA-Z0-9]+', '-')`
-- Türkçe harfleri ASCII'ye çevirmeden SİLİYORDU: "Örnek Züccaciye" →
-- `rnek-z-ccaciye`, "Şık Çarşı" → `k-ar`. Slug storefront adresinde
-- (`?magaza=<slug>`) müşteriye görünür.
--
-- Düzeltme: önce `translate()` ile ç/ğ/ı/İ/ö/ş/ü/â/î/û ASCII karşılığına çevrilir,
-- sonra eski kural uygulanır. `lower()`'dan ÖNCE çevrilir — bazı locale'lerde
-- `lower('İ')` "i̇" (i + birleşik nokta) üretir ve regexp onu da silerdi.
--
-- Gövde = 0041'in gövdesi (bu fonksiyonun tek ve en son tanımı), yalnız slug
-- satırı değişti. İmza/dönüş tipi aynı → `create or replace` yeterli, istemci
-- kodu değişmez.
--
-- ⚠️ MEVCUT kiracıların slug'larına DOKUNULMAZ: slug paylaşılmış storefront
-- linklerinde geçiyor olabilir, değiştirmek o linkleri kırar. Yalnız bundan
-- sonra açılan kiracılar düzgün slug alır.
--
-- Uygulama: Supabase SQL Editor'da çalıştırılır. Idempotenttir.
-- Doğrulama (true dönmeli):
--   select pg_get_functiondef('ensure_tenant_bootstrap(text,text)'::regprocedure) like '%translate(%';
-- =============================================================================

create or replace function ensure_tenant_bootstrap(
  p_tenant_name text default null,
  p_invite_code text default null
) returns tenants as $$
declare
  v_user_id uuid := auth.uid();
  v_meta jsonb;
  v_existing_tenant uuid;
  v_tenant tenants;
  v_invite tenant_invites;
  v_tenant_name text;
  v_slug text;
  v_invite_code text;
begin
  if v_user_id is null then
    raise exception 'Oturum açılmamış.';
  end if;

  select tenant_id into v_existing_tenant from memberships where user_id = v_user_id limit 1;
  if v_existing_tenant is not null then
    select * into v_tenant from tenants where id = v_existing_tenant;
    return v_tenant;
  end if;

  select raw_user_meta_data into v_meta from auth.users where id = v_user_id;

  -- 1) Davet kodu yolu (parametre öncelikli, yoksa signup metadata'sı).
  v_invite_code := coalesce(nullif(trim(p_invite_code), ''), nullif(trim(v_meta->>'pending_invite_code'), ''));
  if v_invite_code is not null then
    select * into v_invite from tenant_invites
    where code = upper(v_invite_code) and used_at is null and expires_at > now()
    for update;

    if not found then
      raise exception 'Davet kodu geçersiz veya süresi dolmuş.';
    end if;

    insert into memberships (user_id, tenant_id, role) values (v_user_id, v_invite.tenant_id, v_invite.role);
    update tenant_invites set used_by = v_user_id, used_at = now() where id = v_invite.id;

    select * into v_tenant from tenants where id = v_invite.tenant_id;
    return v_tenant;
  end if;

  -- 2) Yeni kiracı kurulumu (parametre öncelikli, yoksa signup metadata'sı).
  v_tenant_name := coalesce(
    nullif(trim(p_tenant_name), ''),
    nullif(trim(v_meta->>'pending_tenant_name'), ''),
    'Yeni Mağaza'
  );

  v_slug := translate(v_tenant_name, 'çÇğĞıİöÖşŞüÜâÂîÎûÛ', 'cCgGiIoOsSuUaAiIuU');
  v_slug := lower(regexp_replace(v_slug, '[^a-zA-Z0-9]+', '-', 'g'));
  v_slug := trim(both '-' from v_slug);
  if v_slug = '' then
    v_slug := 'magaza';
  end if;
  while exists (select 1 from tenants where slug = v_slug) loop
    v_slug := v_slug || '-' || substr(md5(random()::text), 1, 4);
  end loop;

  insert into tenants (name, slug) values (v_tenant_name, v_slug)
  returning * into v_tenant;

  insert into memberships (user_id, tenant_id, role) values (v_user_id, v_tenant.id, 'owner');

  return v_tenant;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function ensure_tenant_bootstrap(text, text) to authenticated;
