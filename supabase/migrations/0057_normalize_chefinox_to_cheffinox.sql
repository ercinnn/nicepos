-- =============================================================================
-- 0057: CHEFINOX → CHEFFINOX (doğru yazım) düzeltmesi
-- =============================================================================
-- 0054, "chefinox" (tek F) geçen kayıtları "CHEFINOX" (tek F) olarak
-- normalize etmişti — ancak kullanıcı doğru yazımın ÇİFT F ile "CHEFFINOX"
-- olduğunu belirtti ve `companies` tablosundaki yanlış "CHEFINOX" (tek F)
-- kaydını sildi; artık tek geçerli kayıt "CHEFFINOX". Bu migration 0054'ün
-- ürettiği "CHEFINOX" (tek F) değerlerini "CHEFFINOX"e çevirir.
--
-- "chefinox" (tek F) regex'i "CHEFFINOX" (çift F) içinde ALT-DİZİ OLARAK
-- geçmez (C-H-E-F-F-I-N-O-X sırasında 5. karakter 'f', pozisyon kayması
-- yüzünden "c-h-e-f-i-n-o-x" dizisi oluşmaz) — yani zaten doğru olan
-- kayıtlara bu migration dokunmaz, idempotent'tir.
--
-- CHEFSTAR tamamen FARKLI bir firma — bu migration'dan etkilenmez (regex
-- "chefinox" alt-dizisini arar, "chefstar" bunu içermez).
--
-- Uygulama: anon key ile UPDATE de RLS'ye takılır (yalnız `authenticated`
-- blanket-erişim politikası) → Supabase SQL Editor'da elle çalıştırılmalı.

update products
set description = 'CHEFFINOX'
where description ~* 'chefinox'
returning id, name, description;
