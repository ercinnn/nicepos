-- =============================================================================
-- 0052: "Eksik Listesi" raporundaki DURA firma adı varyantlarını normalize et
-- =============================================================================
-- `products.description` alanı "FIRMA & GG/AA/YY & DURUM" biçiminde firma adını
-- taşır (bkz. `product_repository.dart` `composeDescriptionWithFirma` /
-- `report_repository.dart` `_parseFirmaFromDescription`); bazı kayıtlarda bu
-- format bozuk (örn. "dura_ Cansu 19.2.25 g", "DURA23.12.25") ve firma adı
-- büyük/küçük harf karışık girilmiş (DURA / Dura / dura).
--
-- Bu migration `description` içinde (konumdan bağımsız) "dura" geçen HER
-- kaydı düzeltir. Kural, kayıt DÜZGÜN 3-parça biçimindeyse ("FIRMA &
-- GG/AA/YY & Y|G") farklı, DEĞİLSE ("dura_ Cansu 19.2.25 g", "DURA23.12.25"
-- gibi bozuk/serbest metin) farklı davranır:
--   • Düzgün biçim  → yalnız firma parçası "DURA" olur, " & tarih & durum"
--     AYNEN korunur (bu tarih/durum başka yerlerde de okunuyor, silinmemeli).
--   • Bozuk/serbest metin → TÜM description "DURA" olur (kullanıcı isteği:
--     "içinde dura yazan herşey DURA olsun" — "_ Cansu 19.2.25 g" gibi ek
--     metin dahil silinir, yalnız salt "DURA" kalır).
-- Benzer ama FARKLI bir firma olan "DURU" (örn. "DURU 10/1/25", "duru
-- ahşap") kasıtlı olarak eşleşmez (regex tam "dura" alt-dizisini arar).
--
-- Uygulama: anon key ile UPDATE de RLS'ye takılır (yalnız `authenticated`
-- blanket-erişim politikası) → Supabase SQL Editor'da elle çalıştırılmalı.
-- RETURNING ile kaç/ hangi ürünün değiştiği görülür — çalıştırmadan önce
-- SELECT ile önizleme yapmak isterseniz aşağıdaki yorumlu sorguyu kullanın.

-- Önizleme (isteğe bağlı, önce çalıştırıp etkilenecek satırları görebilirsiniz):
-- select id, name, description
-- from products
-- where description ~* 'dura'
-- order by name;

update products
set description = case
  when description ~ '^.+ & [0-9]{2}/[0-9]{2}/[0-9]{2} & [YG]$'
    then regexp_replace(
      description,
      '^(.+)( & [0-9]{2}/[0-9]{2}/[0-9]{2} & [YG])$',
      'DURA\2'
    )
  else 'DURA'
end
where description ~* 'dura'
returning id, name, description;
