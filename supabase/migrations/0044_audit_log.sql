-- =============================================================================
-- 0044: Audit Log — kalıcı/geri alınamaz işlemler için kim-ne-zaman-ne kaydı
-- =============================================================================
-- Önkoşul: 0036-0043 (Faz A/E — tenants/memberships/current_tenant_id() ve
-- kiracı-bazlı RLS). Rol-bazlı ekran kısıtlamasının (Kasa/maliyet fiyatları/
-- Satışı Sil artık staff'a kapalı) doğal bir uzantısı — "Satışı Sil" gibi
-- kalıcı işlemler için ARTIK yalnız owner/admin sorumlu olduğundan, kimin ne
-- zaman sildiğini görmek isteyen owner/admin için bir kayıt tutulur.
--
-- Kapsam: satış silme (SaleEditScreen + CustomerDetailScreen — iki ayrı ekrandan
-- çağrılabilen AYNI SalesRepository.deleteSale), ürün silme (tekil + toplu),
-- müşteri silme, ödeme/borç hareketi silme (tekil + toplu). Tablo/politika
-- genel amaçlıdır (action/entity_type serbest metin) — ileride başka kalıcı
-- işlemler de aynı tabloya eklenebilir.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (if not exists / drop-then-create policy) — kısmen
-- uygulanmışsa tekrar çalıştırmak güvenlidir.
-- =============================================================================

create table if not exists audit_log (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  actor_user_id uuid not null default auth.uid() references auth.users(id),
  actor_email   text,
  action        text not null,
  entity_type   text not null,
  entity_id     text,
  summary       text not null,
  details       jsonb,
  created_at    timestamptz not null default now()
);

create index if not exists idx_audit_log_tenant_created
  on audit_log (tenant_id, created_at desc);

alter table audit_log enable row level security;

-- Insert: herhangi bir kiracı üyesi kendi kiracısı için yazabilir — tablo
-- ileride staff'a açık kalıcı bir işlem için de kullanılabilsin diye rol
-- kısıtlaması YOK, yalnız tenant izolasyonu var (`tenant_id` DEFAULT +
-- WITH CHECK ile zorlanır, istemci başka bir kiracı adına yazamaz).
drop policy if exists "tenant members insert" on audit_log;
create policy "tenant members insert" on audit_log
  for insert with check (tenant_id = current_tenant_id());

-- Select: yalnız owner/admin — audit log bir denetim aracı, Kasa/maliyet
-- fiyatlarıyla AYNI ilke: staff kendi/başkalarının işlem geçmişini görmez.
drop policy if exists "owner admin select" on audit_log;
create policy "owner admin select" on audit_log
  for select using (
    tenant_id = current_tenant_id()
    and exists (
      select 1 from memberships
      where user_id = auth.uid()
        and tenant_id = audit_log.tenant_id
        and role in ('owner', 'admin')
    )
  );

-- update/delete politikası YOK — audit log immutable (varsayılan RLS reddeder).
