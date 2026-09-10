-- =============================================================================
-- 0055: GÜNDÜZ firma adı varyantlarını normalize et (DURA/CHEFINOX ile aynı desen)
-- =============================================================================
-- Diagnostic sorgu iki AYRI normalize grubu buldu: "gündüz" (Türkçe ü ile,
-- büyük/küçük karışık — 707 ürün) ve "gunduz" (ASCII u ile yazılmış, ü≠u
-- olduğundan case-insensitive eşleşme bunları TEK BAŞINA birleştirmez — 84
-- ürün + "gunduz-" varyantı 2 ürün). Her ikisi de aynı firma, tek bir "GÜNDÜZ"
-- olarak normalize edilir.
--
-- Uygulama: anon key ile UPDATE de RLS'ye takılır (yalnız `authenticated`
-- blanket-erişim politikası) → Supabase SQL Editor'da elle çalıştırılmalı.

update products
set description = 'GÜNDÜZ'
where description ~* 'gündüz' or description ~* 'gunduz'
returning id, name, description;
