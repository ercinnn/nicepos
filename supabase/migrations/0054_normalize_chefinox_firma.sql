-- =============================================================================
-- 0054: CHEFINOX firma adı varyantlarını normalize et (DURA/0052-0053 ile aynı desen)
-- =============================================================================
-- `products.description` içinde (konumdan bağımsız, biçimden bağımsız) "chefinox"
-- geçen HER kaydı salt "CHEFINOX" yapar — tarih/durum dahil geri kalan her şey
-- silinir (0053'teki DURA sadeleştirmesiyle birebir aynı kural).
--
-- Benzer ama FARKLI bir firma olan "CHEFSTAR" (örn. "CHEFSTAR PEYNİR KESİCİ",
-- "Chefstar") kasıtlı olarak eşleşmez — regex tam "chefinox" alt-dizisini arar,
-- "chefstar" bunu içermez.
--
-- Uygulama: anon key ile UPDATE de RLS'ye takılır (yalnız `authenticated`
-- blanket-erişim politikası) → Supabase SQL Editor'da elle çalıştırılmalı.

update products
set description = 'CHEFINOX'
where description ~* 'chefinox'
returning id, name, description;
