# Uygulanan Migration'lar

Bu dosya, `supabase/migrations/*.sql` dosyalarından hangisinin **gerçekten** Supabase SQL Editor'da çalıştırıldığını takip eder. DDL anon key ile uygulanamadığından her migration kullanıcı tarafından elle çalıştırılır — bu dosya olmadan "hangisi uygulandı" sorusu belirsiz kalıyordu (0050/0051 karışıklığı, bkz. CLAUDE.md).

**Kural:** Yeni bir migration yazınca bu dosyaya `beklemede` satırı olarak eklenir; kullanıcı Supabase SQL Editor'da çalıştırdığını doğrulayınca satır `uygulandı` + tarihe güncellenir.

| Migration | Durum | Tarih | Not |
|---|---|---|---|
| 0001–0049 | uygulandı (varsayım) | — | Bu dosya 2026-09-02'de açıldı; bu tarihten önceki migration'ların tam uygulanma tarihi kayıtlı değil, ancak ilgili özellikler (satış, ürün, etiket, kasa, çok kiracılı mimari, storefront, domain satın alma altyapısı) canlıda çalıştığından uygulanmış oldukları kabul ediliyor. |
| 0050_discount_recommendations.sql | uygulandı | 2026-09-01 (yaklaşık) | Kullanıcı canlıda test etti, sonuç döndü ("sadece 4-5 ürün var"). |
| 0051_discount_recommendations_v2.sql | **beklemede** | — | 0050'nin dönüş kolonlarını değiştirdiği için önce `DROP FUNCTION` içeriyor — uygulanmadan tab eski (0050) davranışını göstermeye devam eder ya da hata verir. |
