-- =============================================================================
-- 0053: DURA firma adını düzgün biçimli kayıtlarda da sadeleştir
-- =============================================================================
-- 0052, düzgün "FIRMA & GG/AA/YY & DURUM" biçimindeki kayıtlarda yalnız firma
-- parçasını "DURA" yapıp tarih/durum kısmını koruyordu (örn. "DURA &
-- 20/08/26 & Y"). Kullanıcı bunun da yalnız "DURA" olmasını istedi — biçimden
-- bağımsız, `description` içinde "dura" geçen HER kayıt artık salt "DURA"
-- olur (tarih/durum dahil her şey silinir).
--
-- Benzer ama FARKLI bir firma olan "DURU" (örn. "DURU 10/1/25", "duru
-- ahşap") kasıtlı olarak eşleşmez (regex tam "dura" alt-dizisini arar).
--
-- Uygulama: anon key ile UPDATE de RLS'ye takılır (yalnız `authenticated`
-- blanket-erişim politikası) → Supabase SQL Editor'da elle çalıştırılmalı.

update products
set description = 'DURA'
where description ~* 'dura'
returning id, name, description;
