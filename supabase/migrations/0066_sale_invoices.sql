-- =============================================================================
-- 0066: e-Fatura/e-Arşiv (EDM Bilişim) — talep/durum kuyruğu
-- =============================================================================
-- Amaç: NicePOS'ta "Fatura Kes" butonu doğrudan EDM'yi ÇAĞIRMAZ (Python script
-- kullanıcının kendi bilgisayarında elle çalıştırılır, sürekli sunucu yok) —
-- buton yalnız bu tabloya bir `pending` satırı yazar, script bunu okuyup EDM'ye
-- gönderir ve sonucu buraya yazar. Detay: notes/e-fatura-entegrasyonu.md
--
-- RLS deseni `audit_log` (0044) ile BİREBİR aynı: insert/select kiracı üyesine
-- açık, update/delete politikası YOK (Python script `service_role` key ile
-- zaten RLS'i bypass eder, istemciden asla update gelmemeli).
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (if not exists / drop-then-create policy).
-- =============================================================================

create table if not exists sale_invoices (
  id             uuid primary key default gen_random_uuid(),
  sale_id        uuid not null references sales(id) on delete cascade,
  tenant_id      uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  invoice_type   text not null check (invoice_type in ('e_fatura', 'e_arsiv')),
  status         text not null default 'pending' check (status in ('pending', 'sent', 'failed')),
  edm_invoice_id text,
  pdf_url        text,
  error_message  text,
  requested_by   text,
  requested_at   timestamptz not null default now(),
  completed_at   timestamptz
);

-- Bir satış için aynı anda tek aktif talep (pending/sent) — failed satır yeni
-- bir denemeyle serbest kalır (aynı sale_id ile tekrar insert edilebilir).
create unique index if not exists idx_sale_invoices_active_per_sale
  on sale_invoices (sale_id)
  where status in ('pending', 'sent');

create index if not exists idx_sale_invoices_tenant_status
  on sale_invoices (tenant_id, status);

alter table sale_invoices enable row level security;

drop policy if exists "tenant members insert" on sale_invoices;
create policy "tenant members insert" on sale_invoices
  for insert with check (tenant_id = current_tenant_id());

drop policy if exists "tenant members select" on sale_invoices;
create policy "tenant members select" on sale_invoices
  for select using (tenant_id = current_tenant_id());

-- update/delete politikası YOK — istemciden asla gelmemeli, yalnız Python
-- script'in kullandığı service_role key RLS'i zaten bypass eder.
