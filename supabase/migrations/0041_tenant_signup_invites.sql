-- =============================================================================
-- 0041: Kendi-kendine kayıt + personel davet — Faz B / Adım 1
-- =============================================================================
-- Önkoşul: 0036-0040 (Faz A — tenants/memberships/current_tenant_id() ve
-- kiracı-bazlı RLS/RPC'ler).
--
-- Bu migration İKİ akışı tek bir atomik RPC'de (`ensure_tenant_bootstrap`)
-- birleştirir:
--   1) Yeni işletme kaydı: kullanıcı e-posta/şifre ile `auth.signUp()` yapar,
--      RPC yeni bir `tenants` satırı açıp kullanıcıyı 'owner' yapar.
--   2) Davet koduyla katılma: kullanıcı bir sahibin ürettiği kodu girer, RPC
--      MEVCUT bir kiracıya kullanıcıyı belirtilen rolle üye yapar.
--
-- Gecikmeli e-posta onayı senaryosu (Supabase projesinde "Confirm email"
-- açıksa `auth.signUp()` hemen bir oturum döndürmez — kullanıcı e-postadaki
-- bağlantıya tıklayıp SONRA giriş yapar): şirket adı / davet kodu bu yüzden
-- `auth.signUp()`'ın `data:` parametresiyle (`user_metadata`) saklanır; RPC
-- parametre olarak hiçbir şey verilmese bile bu metadata'ya bakar — istemci
-- ilk başarılı girişte parametresiz `ensure_tenant_bootstrap()` çağırarak
-- kurulumu tamamlayabilir (bkz. Dart: `ensureTenantProvisionedProvider`).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir — kısmen uygulanmışsa tekrar çalıştırmak güvenlidir.
-- =============================================================================

create table if not exists tenant_invites (
  id         uuid primary key default gen_random_uuid(),
  tenant_id  uuid not null references tenants(id) on delete cascade,
  code       text not null unique,
  role       text not null default 'staff' check (role in ('owner','admin','staff')),
  created_by uuid references auth.users(id),
  used_by    uuid references auth.users(id),
  used_at    timestamptz,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days')
);

create index if not exists idx_tenant_invites_tenant_id on tenant_invites (tenant_id);

alter table tenant_invites enable row level security;

drop policy if exists "tenant scoped read" on tenant_invites;
create policy "tenant scoped read" on tenant_invites
  for select using (tenant_id = current_tenant_id());

-- Yalnız owner/admin kendi kiracısının kullanılmamış davetini iptal edebilir.
-- Insert/update client'tan doğrudan YAPILMAZ — yalnız aşağıdaki RPC'ler üzerinden.
drop policy if exists "owner admin delete" on tenant_invites;
create policy "owner admin delete" on tenant_invites
  for delete using (
    tenant_id = current_tenant_id()
    and exists (
      select 1 from memberships
      where user_id = auth.uid()
        and tenant_id = tenant_invites.tenant_id
        and role in ('owner', 'admin')
    )
  );

-- -----------------------------------------------------------------------------
-- ensure_tenant_bootstrap — TEK atomik giriş noktası (yeni kiracı VEYA davet ile katılma)
-- -----------------------------------------------------------------------------
-- Zaten bir üyeliği olan kullanıcı için NO-OP'tur (mevcut kiracıyı döndürür) —
-- bu, hem signup ekranından hemen sonra hem de her girişte güvenle
-- çağrılabilmesini sağlar (idempotent).
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

  v_slug := lower(regexp_replace(v_tenant_name, '[^a-zA-Z0-9]+', '-', 'g'));
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

-- -----------------------------------------------------------------------------
-- create_tenant_invite — yalnız owner/admin, kendi kiracısı için kod üretir
-- -----------------------------------------------------------------------------
create or replace function create_tenant_invite(p_role text default 'staff')
returns tenant_invites as $$
declare
  v_tenant_id uuid;
  v_caller_role text;
  v_role text;
  v_code text;
  v_invite tenant_invites;
begin
  select tenant_id, role into v_tenant_id, v_caller_role
  from memberships where user_id = auth.uid() limit 1;

  if v_tenant_id is null then
    raise exception 'Kiracı bulunamadı.';
  end if;
  if v_caller_role not in ('owner', 'admin') then
    raise exception 'Bu işlem için yetkiniz yok.';
  end if;

  v_role := coalesce(p_role, 'staff');
  if v_role not in ('admin', 'staff') then
    raise exception 'Geçersiz rol: %', v_role;
  end if;

  loop
    v_code := upper(substr(md5(random()::text), 1, 8));
    exit when not exists (select 1 from tenant_invites where code = v_code);
  end loop;

  insert into tenant_invites (tenant_id, code, role, created_by)
  values (v_tenant_id, v_code, v_role, auth.uid())
  returning * into v_invite;

  return v_invite;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function create_tenant_invite(text) to authenticated;
