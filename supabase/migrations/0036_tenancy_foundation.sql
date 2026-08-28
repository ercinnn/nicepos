-- =============================================================================
-- 0036: Çoklu Kiracı (Multi-Tenant) Temeli — Faz A / Adım 1
-- =============================================================================
-- Amaç: NicePOS'u tek şirket için değil, birden çok şirkete SaaS olarak
-- satılabilecek şekilde dönüştürmenin ilk (ve engelleyici) adımı. Bu migration
-- yalnızca TEMEL modeli kurar: `tenants` (kiracı/şirket) + `memberships`
-- (kullanıcı ↔ kiracı ↔ rol) tabloları + `current_tenant_id()` çözümleyici
-- fonksiyonu. Mevcut iş tablolarına `tenant_id` eklemek 0037'nin, RLS'i
-- kiracı-bazlı yeniden yazmak 0039'un işidir — bu dosya yalnızca temeli atar.
--
-- Geriye dönük uyumluluk (KRİTİK): Bu migration'ın sonunda, uygulamanın şu anki
-- tek şirketi otomatik olarak "1. kiracı" (tenant #1) olur ve MEVCUT tüm
-- Supabase Auth kullanıcıları bu kiracıya 'owner' rolüyle üye yapılır — ayrı
-- bir veri taşıma/export-import GEREKMEZ, uygulama 0037-0040 sonrasında aynı
-- şekilde çalışmaya devam eder.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (if not exists / on conflict) — kısmen uygulanmışsa tekrar
-- çalıştırmak güvenlidir.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1) tenants — her satış yapılan şirket/mağaza
-- -----------------------------------------------------------------------------
create table if not exists tenants (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  slug       text not null unique,
  plan       text not null default 'trial',
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- 2) memberships — hangi kullanıcı hangi kiracıda hangi rolde
-- -----------------------------------------------------------------------------
create table if not exists memberships (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  tenant_id  uuid not null references tenants(id) on delete cascade,
  role       text not null default 'owner' check (role in ('owner','admin','staff')),
  created_at timestamptz not null default now(),
  unique (user_id, tenant_id)
);

create index if not exists idx_memberships_user_id on memberships (user_id);
create index if not exists idx_memberships_tenant_id on memberships (tenant_id);

-- -----------------------------------------------------------------------------
-- 3) current_tenant_id() — TEK çözümleme noktası
-- -----------------------------------------------------------------------------
-- Çağıran kullanıcının (auth.uid()) hangi kiracıya ait olduğunu döndürür.
-- SECURITY DEFINER: memberships üzerindeki RLS'e bağımlı olmadan, her zaman
-- güvenle çalışır (search_path sabitlenir — SECURITY DEFINER güvenlik pratiği).
-- v1'de bir kullanıcı TEK kiracıya üye olabilir (limit 1) — çoklu kiracı/rol
-- değiştirme Faz B'nin kapsamındadır.
create or replace function current_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select tenant_id from memberships where user_id = auth.uid() limit 1;
$$;

grant execute on function current_tenant_id() to anon, authenticated;

alter table tenants enable row level security;
alter table memberships enable row level security;

drop policy if exists "select own tenant" on tenants;
create policy "select own tenant" on tenants
  for select using (id = current_tenant_id());

drop policy if exists "select own memberships" on memberships;
create policy "select own memberships" on memberships
  for select using (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- 4) Geri-doldurma: mevcut şirket = "1. kiracı", mevcut TÜM kullanıcılar owner
-- -----------------------------------------------------------------------------
-- Sabit UUID kasıtlı: 0037'deki her tabloya tenant_id geri-doldurmasında da
-- AYNI değer kullanılacak — iki migration arasında tutarlılığı garanti eder.
insert into tenants (id, name, slug)
values ('00000000-0000-0000-0000-000000000001', 'NicePOS - İlk Mağaza', 'ilk-magaza')
on conflict (id) do nothing;

insert into memberships (user_id, tenant_id, role)
select id, '00000000-0000-0000-0000-000000000001', 'owner'
from auth.users
on conflict (user_id, tenant_id) do nothing;
