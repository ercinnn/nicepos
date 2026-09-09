-- =============================================================================
-- 0047: Kiracı domain satın alma — durum takip tablosu + tek client RPC'si
-- =============================================================================
-- Kullanıcı isteği: kiracılar Online Satış ekranından kendi domain'lerini
-- arayıp satın alabilsin, otomatik kayıt olup storefront'a bağlansın.
-- Cloudflare Registrar API domain'i BİZİM hesabımıza kaydediyor (kiracının
-- kendi kartıyla ödeme yapması mümkün değil — "Successful registrations are
-- billable to the default payment profile"), bu yüzden önce kiracıdan iyzico
-- ile tahsilat yapılıyor, sonra platform Cloudflare'e kaydediyor. Tüm dış
-- HTTP çağrıları (Cloudflare/iyzico) Supabase Edge Functions'ta yaşıyor
-- (supabase/functions/) — Postgres kendi başına dış HTTP çağrısı yapamaz.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (create table if not exists / create or replace).
-- =============================================================================

create table if not exists domain_purchases (
  id                       uuid primary key default gen_random_uuid(),
  tenant_id                uuid not null default current_tenant_id() references tenants(id) on delete cascade,
  created_by               uuid not null default auth.uid() references auth.users(id),

  domain                   text not null,
  price_amount             numeric(10,2) not null,       -- Cloudflare maliyet fiyatı (hizmet bedeli HARİÇ)
  price_currency           text not null,
  service_fee_percent      numeric(5,2) not null default 25, -- v1 kararı: %25, kayıt altında (ileride değişebilir)
  registrant_contact       jsonb not null,                -- Cloudflare'e/iyzico'ya gönderilen tam kişi bilgisi

  status                   text not null default 'payment_pending'
                             check (status in (
                               'payment_pending', 'paid', 'registering', 'registered',
                               'connecting_dns', 'connected', 'failed'
                             )),
  failure_stage            text,                          -- 'price_check' | 'registering' | 'connecting_dns' | 'timeout'
  needs_manual_review      boolean not null default false,
  last_error               jsonb,

  iyzico_conversation_id   text,
  iyzico_token             text,
  iyzico_payment_id        text,
  iyzico_raw_status        text,

  cf_registration_id       text,
  cf_zone_id               text,
  cf_raw_status             text,
  dns_record_id             text,
  pages_domain_status       text,

  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

create index if not exists idx_domain_purchases_tenant on domain_purchases (tenant_id, created_at desc);
create index if not exists idx_domain_purchases_status on domain_purchases (status);
create unique index if not exists idx_domain_purchases_conversation on domain_purchases (iyzico_conversation_id);

alter table domain_purchases enable row level security;

-- Yalnız SELECT — owner/admin kendi kiracısının satın alma denemelerini
-- görebilir (audit_log 0044 ile aynı desen: finansal/hassas veri, staff'a
-- kapalı). Client'a doğrudan INSERT/UPDATE RLS'i verilmez — tek client
-- yazma yolu aşağıdaki RPC, sonraki tüm durum geçişleri Edge Function'ların
-- service-role client'ıyla yapılır (webhook/cron bağlamında "acting user"
-- olmadığından RPC değil, doğrudan servis-rolü yazımı kullanılır).
drop policy if exists "owner admin select own tenant" on domain_purchases;
create policy "owner admin select own tenant" on domain_purchases
  for select using (
    tenant_id = current_tenant_id()
    and exists (
      select 1 from memberships
      where user_id = auth.uid()
        and tenant_id = domain_purchases.tenant_id
        and role in ('owner', 'admin')
    )
  );

-- Client-çağrılabilir TEK insert yolu — `domain-purchase-initiate` Edge
-- Function'ı bunu kullanıcının KENDİ JWT'siyle çağırır (current_tenant_id()
-- doğru çözülsün diye), service-role ile DEĞİL.
create or replace function create_domain_purchase_request(
  p_domain text,
  p_price_amount numeric,
  p_price_currency text,
  p_registrant_contact jsonb,
  p_iyzico_conversation_id text,
  p_iyzico_token text
) returns domain_purchases as $$
declare
  v_tenant_id uuid;
  v_role text;
  v_row domain_purchases;
begin
  select tenant_id, role into v_tenant_id, v_role
  from memberships where user_id = auth.uid() limit 1;

  if v_tenant_id is null then
    raise exception 'Kiracı bulunamadı.';
  end if;
  if v_role not in ('owner', 'admin') then
    raise exception 'Bu işlem için yetkiniz yok.';
  end if;
  if trim(p_domain) = '' then
    raise exception 'Domain adı boş olamaz.';
  end if;

  insert into domain_purchases (
    tenant_id, domain, price_amount, price_currency,
    registrant_contact, iyzico_conversation_id, iyzico_token
  ) values (
    v_tenant_id, p_domain, p_price_amount, p_price_currency,
    p_registrant_contact, p_iyzico_conversation_id, p_iyzico_token
  ) returning * into v_row;

  return v_row;
end;
$$ language plpgsql security definer set search_path = public;

grant execute on function create_domain_purchase_request(text, numeric, text, jsonb, text, text) to authenticated;
