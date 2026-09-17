-- =============================================================================
-- 0064: e-Fatura/e-Arşiv (EDM Bilişim) ön hazırlığı — kiracı fatura bilgileri
-- =============================================================================
-- Amaç: Resmi bir e-Fatura/e-Arşiv çıktısı üretebilmek için satıcı tarafının
-- (kiracının) unvan/vergi no/vergi dairesi/adres bilgisi gerekir — `tenants`
-- tablosu şu ana kadar yalnız `name`/`slug` tutuyordu, bunlar fatura için
-- yeterli değil. Detay: notes/e-fatura-entegrasyonu.md
--
-- Hepsi nullable + varsayılansız — mevcut kiracı (ilk mağaza) bozulmaz, alanlar
-- Online Satış kontrol panelinden veya elle Supabase Studio'dan doldurulur.
--
-- Uygulama: DDL anon key ile çalıştırılamaz → Supabase SQL Editor'da uygulanır.
-- Idempotenttir (add column if not exists).
-- =============================================================================

alter table tenants
  add column if not exists unvan text,
  add column if not exists vergi_no text,
  add column if not exists vergi_dairesi text,
  add column if not exists adres text,
  add column if not exists il text,
  add column if not exists ilce text,
  add column if not exists e_fatura_mukellefi boolean not null default false;
