-- =============================================================================
-- 0012: customer_payments.channel — borç tahsilatı kanalı (nakit / pos)
-- =============================================================================
-- Amaç: Müşteri açık hesap borç tahsilatının NAKİT mi POS mu alındığını
-- kaydetmek. Bu bilgi Kasa gün sonu mutabakatında (Faz C) sistem tabanının
-- doğru kanala (nakit tabanı vs POS tabanı) eklenmesi için gereklidir.
--
-- Uygulama sırası (Supabase SQL Editor'da, anon key ile DDL çalışmaz):
--   1) Bu dosyanın TAMAMINI SQL Editor'a yapıştır ve çalıştır.
--   2) Idempotenttir (add column if not exists) — kısmen uygulanmışsa tekrar
--      çalıştırmak güvenlidir.
--
-- Geriye dönük uyumluluk:
--   • Eski tahsilat kayıtlarında channel = NULL kalır ve NAKİT sayılır
--     (mutabakat motoru `channel = 'nakit' OR channel IS NULL` süzer).
--   • channel yalnız type='odeme' (tahsilat) kayıtlarında dolar; type='borc'
--     (borç ekleme) kayıtlarında NULL kalır.
--
-- Güvenlik: customer_payments YENİ tablo DEĞİL, yalnız KOLON eklenir → mevcut
-- RLS politikası (0002_rls.sql "authenticated full access") aynen korunur,
-- yeniden tanımlanmaz.
-- =============================================================================

alter table customer_payments
  add column if not exists channel text null
    check (channel in ('nakit','pos'));
