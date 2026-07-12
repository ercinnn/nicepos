-- =============================================================================
-- 0011: KASA (Kasa Defteri) — Faz A DDL taslağı
-- =============================================================================
-- Bu migration Kasa (günlük gelir/gider defteri + banka/POS mutabakatı) için
-- gereken TABLOLARI ve KOLONLARI oluşturur. UYGULAMA MANTIĞI YOKTUR
-- (mutabakat hesabı Faz C'de Dart tarafında yapılır; buradaki mantık yalnızca
-- SQL YORUMU olarak belgelenmiştir).
--
-- Uygulama sırası (Supabase SQL Editor'da, anon key ile DDL çalışmaz):
--   1) Bu dosyanın TAMAMINI SQL Editor'a yapıştır ve çalıştır.
--   2) Idempotenttir (if not exists / add column if not exists / on conflict) —
--      kısmen uygulanmışsa tekrar çalıştırmak güvenlidir.
--
-- Tasarım kararları (kullanıcı ile ONAYLANDI):
--   • Defter YIL BAZLIDIR (fiscal_year). 2027 sıfırdan başlar; otomatik devir
--     yoktur. Yeni yıl açılış bakiyeleri kasa_opening_balances'a elle girilir.
--   • POS bankaları (Akbank / İş Bankası / Garanti) ayrımı SADECE Kasa UI'ında
--     yaşar; sales tablosuna banka kolonu EKLENMEZ. POS mutabakatı üç bankanın
--     toplamı üzerinden yürür.
--   • Mutabakat farkı, kalemsiz/stoksuz bir "düzeltme satışı" (is_adjustment=true)
--     olarak sales'e yazılır; ciroya dahildir ama stok hareketi üretmez.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- 1) kasa_entries — günlük gelir/gider kalemleri
-- -----------------------------------------------------------------------------
-- Kasa defterindeki elle girilen her gelir/gider satırı. Satış cirosu buraya
-- yazılmaz (o sales'ten gelir); burası ekstra gelirler ve giderler içindir.
--   direction = 'gelir' | 'gider'
--   channel   = 'nakit' | 'pos'  (gelir kanalı; gider için NULL olabilir)
--   category  = gider kategorisi adı (kasa_expense_categories.name ile eşleşir;
--               serbest metin, FK değil — kategori silinse bile geçmiş korunur)
--   company_id= gider firması (companies tablosu; '/' ile autocomplete)
create table if not exists kasa_entries (
  id          uuid primary key default gen_random_uuid(),
  entry_date  date not null,
  fiscal_year int  not null,
  direction   text not null check (direction in ('gelir','gider')),
  channel     text     null check (channel in ('nakit','pos')),
  category    text     null,
  company_id  uuid     null references companies(id),
  amount      numeric not null,
  note        text     null,
  created_at  timestamptz not null default now()
);
create index if not exists kasa_entries_date_idx        on kasa_entries (entry_date);
create index if not exists kasa_entries_fiscal_year_idx on kasa_entries (fiscal_year);
create index if not exists kasa_entries_company_idx     on kasa_entries (company_id);

-- -----------------------------------------------------------------------------
-- 2) kasa_expense_categories — gider kategorileri (autocomplete kaynağı)
-- -----------------------------------------------------------------------------
-- name unique: aynı kategori iki kez eklenemez. is_active=false ile kategori
-- listeden gizlenir ama geçmiş kayıtlar bozulmaz (kasa_entries.category serbest
-- metin tuttuğu için).
create table if not exists kasa_expense_categories (
  id        uuid primary key default gen_random_uuid(),
  name      text not null unique,
  is_active boolean not null default true
);

-- Seed: temel gider kategorileri (tekrar çalıştırmada çakışma yaratmaz)
insert into kasa_expense_categories (name) values
  ('Kira'),
  ('Muhasebe'),
  ('Muhtelif')
on conflict (name) do nothing;

-- -----------------------------------------------------------------------------
-- 3) kasa_opening_balances — yıl başı açılış bakiyeleri (yıl bazlı)
-- -----------------------------------------------------------------------------
-- fiscal_year PRIMARY KEY: her yıl için TEK açılış satırı.
--   opening_income : açılış geliri — Nakit + POS BİRLEŞİK tek kalem
--   opening_expense: açılış gideri — tek kalem
-- Otomatik devir yok; yeni yıl bakiyesi buraya elle yazılır.
create table if not exists kasa_opening_balances (
  fiscal_year     int primary key,
  opening_income  numeric not null default 0,
  opening_expense numeric not null default 0,
  note            text null
);

-- -----------------------------------------------------------------------------
-- 4) sales kolon eklemeleri — mutabakat düzeltme satışları
-- -----------------------------------------------------------------------------
-- is_adjustment=true olan sales kaydı, gün sonu kasa mutabakatında oluşan
-- +fark (ek gelir) veya -fark (iade) satırıdır. Kalemsiz (sale_items yok),
-- stoksuz (stok RPC'si çağrılmaz) ama ciroya dahildir.
--   adjustment_channel: düzeltmenin hangi kanala ait olduğu ('nakit'|'pos').
--                       Normal satışlarda NULL kalır.
alter table sales
  add column if not exists is_adjustment      boolean not null default false,
  add column if not exists adjustment_channel text null
    check (adjustment_channel in ('nakit','pos'));

-- Düzeltme satışlarını hızlı süzmek için kısmi indeks.
create index if not exists sales_is_adjustment_idx
  on sales (is_adjustment) where is_adjustment = true;

-- -----------------------------------------------------------------------------
-- 5) kasa_reconciliations — gün+kanal mutabakat idempotentliği
-- -----------------------------------------------------------------------------
-- Aynı gün + aynı kanal için mutabakat tekrar kaydedilirse ESKİ düzeltme satırı
-- güncellenir; yeni hayalet düzeltme birikmez. Bu tabloda o gün/kanal için
-- üretilmiş düzeltme satışının (sale_id) izi tutulur.
--
--   expected_amount : kullanıcının kasaya YAZDIĞI gerçek tutar (o gün/o kanal)
--   system_base     : sistemin o gün/kanal için hesapladığı taban
--   adjustment_amount = expected_amount - system_base
--                       ( +  → ek gelir düzeltmesi
--                         -  → iade düzeltmesi )
create table if not exists kasa_reconciliations (
  id                uuid primary key default gen_random_uuid(),
  fiscal_year       int  not null,
  entry_date        date not null,
  channel           text not null check (channel in ('nakit','pos')),
  sale_id           uuid null references sales(id),
  expected_amount   numeric,
  system_base       numeric,
  adjustment_amount numeric,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  -- Gün + kanal başına TEK mutabakat satırı → idempotentlik garantisi.
  constraint kasa_reconciliations_day_channel_uq
    unique (fiscal_year, entry_date, channel)
);
create index if not exists kasa_reconciliations_date_idx on kasa_reconciliations (entry_date);

-- =============================================================================
-- MUTABAKAT MANTIĞI (BELGE — uygulama Faz C'de Dart'ta yapılacak)
-- =============================================================================
-- Amaç: Kullanıcının gün sonunda kasada/bankada gördüğü GERÇEK tutar ile
-- sistemin satışlardan hesapladığı tutarı eşitlemek; fark kadar bir düzeltme
-- satışı üretmek.
--
-- (A) Sistem tabanı (o gün, o kanal için):
--       system_base(kanal) =
--           o günkü satış geliri(kanal)
--         + o gün yapılan açık hesap borç TAHSİLATLARI(kanal)
--
--     • Nakit taban  = payment_type nakit satışların cash_amount toplamı
--                      + parçalı satışların cash_amount'u
--                      + o gün customer_payments type='odeme' NAKİT tahsilatlar
--     • POS taban    = payment_type pos satışların card_amount toplamı
--                      + parçalı satışların card_amount'u
--                      + o gün customer_payments type='odeme' POS tahsilatlar
--       POS taban, üç bankanın (Akbank + İş Bankası + Garanti) TOPLAMIDIR;
--       banka ayrımı yalnızca Kasa UI'ında yapılır, sales'e yansımaz.
--
-- (B) Düzeltme tutarı:
--       adjustment_amount = expected_amount - system_base
--       • adjustment_amount > 0 → +düzeltme (ek gelir): sisteme eksik giren
--         gerçek para; is_adjustment=true bir sales kaydı EKLENİR
--         (total_amount = +fark, adjustment_channel = kanal).
--       • adjustment_amount < 0 → -düzeltme (iade/eksik): total_amount = -fark.
--       • adjustment_amount = 0 → düzeltme satırı OLUŞTURULMAZ (varsa silinir).
--
-- (C) İdempotentlik (kasa_reconciliations üzerinden):
--       Aynı (fiscal_year, entry_date, channel) için:
--         - Kayıt YOKSA: düzeltme satışı üret, sale_id'yi buraya yaz.
--         - Kayıt VARSA: mevcut sale_id'li düzeltme satışını yeni farkla
--           GÜNCELLE (veya fark 0 olduysa düzeltme satışını sil + sale_id=null).
--       UNIQUE(fiscal_year, entry_date, channel) bu tekilliği DB düzeyinde
--       garanti eder; upsert (on conflict) ile yeni hayalet birikmez.
--
-- (D) Örnek doğrulama:
--       system_base(nakit) = 1.000 ₺ ; kullanıcının yazdığı expected = 1.050 ₺
--       → adjustment_amount = 1.050 - 1.000 = +50 ₺ (ek gelir)
--       → is_adjustment=true, adjustment_channel='nakit', total_amount=50 sales.
--       Ertesi gün kullanıcı 1.050'yi 1.020 olarak düzeltirse:
--       → aynı gün/kanal kaydı bulunur, düzeltme 50 → 20'ye GÜNCELLENİR
--         (yeni satır AÇILMAZ). Fark 0 olsaydı düzeltme satırı silinirdi.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 6) RLS (Row Level Security) — 0002_rls.sql deseninin birebir devamı
-- -----------------------------------------------------------------------------
-- Bu projede güvenlik RLS ile sağlanır (ayrı GRANT yoktur): giriş yapmış
-- (authenticated) her kullanıcı tam CRUD erişimine sahiptir; anon erişemez.
-- Yeni tabloların HER BİRİNDE RLS açılır ve aynı "authenticated full access"
-- politikası tanımlanır. (sales'e yalnızca kolon eklendiği için o tablonun
-- mevcut politikası geçerli kalır; tekrar tanımlanmaz.)
alter table kasa_entries            enable row level security;
alter table kasa_expense_categories enable row level security;
alter table kasa_opening_balances   enable row level security;
alter table kasa_reconciliations    enable row level security;

-- Postgres 'create policy'yi if-not-exists desteklemez; tekrar çalıştırmada
-- "policy already exists" hatası vermemesi için önce drop-if-exists yapılır.
drop policy if exists "authenticated full access" on kasa_entries;
create policy "authenticated full access" on kasa_entries
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access" on kasa_expense_categories;
create policy "authenticated full access" on kasa_expense_categories
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access" on kasa_opening_balances;
create policy "authenticated full access" on kasa_opening_balances
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access" on kasa_reconciliations;
create policy "authenticated full access" on kasa_reconciliations
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');