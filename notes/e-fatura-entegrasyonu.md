# e-Fatura/e-Arşiv Entegrasyonu (EDM Bilişim)

Kullanıcı zaten e-Fatura mükellefi ve EDM Bilişim'in entegratör hizmetini kullanıyor, ama şu an faturaları NicePOS'tan bağımsız, elle/başka bir arayüzden kesiyor. Amaç: bir satışı seçip NicePOS'tan resmi fatura talebi oluşturabilmek.

**Durum: EDM API bilgileri (kullanıcı adı/şifre, endpoint, format) henüz yok.** DB şeması + Flutter UI + Python iskeleti ilerletildi (bkz. aşağıdaki "Tamamlanan" bölümü); yalnız gerçek EDM çağrısı (`efatura/edm_client.py` içindeki `send_invoice()`) bekliyor. Bu yüzden CLAUDE.md'nin üstündeki "⏸️ Beklemede" tablosuna EKLENMEDİ (o tablo "hiçbir ilerleme mümkün değil" anlamına geliyor, burada durum farklı) — yalnız bu not dosyasında takip edilir.

## Mimari Kararlar

- **Tetikleme manuel:** her satışta otomatik değil, kullanıcı hangi satışın resmi fatura gerektirdiğine kendi karar veriyor (Türkiye'de her POS satışı e-Arşiv gerektirmez).
- **Python yerelde, elle çalıştırılır:** sürekli açık bir sunucu/hosting yok. NicePOS (Flutter web/mobil) yalnız bir talep/durum satırı yazar (`sale_invoices`), Python script kullanıcının kendi bilgisayarında `python -m efatura.main` ile elle çalıştırılıp bu satırları işler.
- **Akış:** `SaleEditScreen`'de "Fatura Kes" → tür seçimi (e-Fatura/e-Arşiv) → `sale_invoices`'a `pending` satırı → kullanıcı script'i çalıştırır → script `pending` satırları okuyup EDM'ye gönderir → `sent`/`failed` olarak günceller → NicePOS bir sonraki açılışta durumu gösterir (pending/sent/failed rozeti).

## Tamamlanan (DB + UI + Python iskeleti)

- **Migration'lar:**
  - `0064_tenant_invoice_fields.sql` — `tenants`'a `unvan/vergi_no/vergi_dairesi/adres/il/ilce/e_fatura_mukellefi` (nullable).
  - `0065_sale_items_vat_snapshot.sql` — `sale_items`'a `vat_rate`/`vat_amount` (satış anı KDV donması, `complete_sale`/`complete_sale_offline` RPC'leri güncellendi). Geriye dönük satırlar NULL kalır — fatura özelliği yalnız bundan sonraki satışlarda kullanılabilir. `vat_amount` fiyatların KDV DAHİL olduğu varsayımıyla satır toplamından geriye ayrıştırılır (`total - total/(1+vat_rate/100)`) — EDM'nin gerçek beklediği yuvarlama/format farklı çıkarsa bu formül migration'da güncellenir.
  - `0066_sale_invoices.sql` — talep/durum kuyruğu tablosu, RLS `audit_log` (0044) deseniyle birebir (insert/select kiracı üyesine açık, update/delete politikası yok — Python script `service_role` key ile zaten RLS'i bypass eder).
  - **⚠️ Henüz Supabase SQL Editor'da uygulanmadı** — kullanıcı uyguladığını doğrulayınca `supabase/migrations/APPLIED.md`'ye eklenecek.
- **Flutter:** `lib/features/sales/data/models/sale_invoice.dart` (model), `SalesRepository.requestInvoice()`/`fetchLatestInvoice()`, `SaleEditScreen`'de "Fatura Kes" butonu (Yazdır'ın yanında, tüm platformlarda görünür) + durum rozeti (`_buildInvoiceStatus`).
- **Python:** kökte `efatura/` klasörü — `main.py` (CLI, pending kayıtları işler), `edm_client.py` (stub, `NotImplementedError`), `.env.example`, `requirements.txt`.

## EDM'den İstenmesi Gereken Somut Liste

1. API kullanıcı adı/şifre (test + canlı ortam ayrı mı?)
2. Test ve canlı ortam endpoint'leri (WSDL/SOAP mu, REST/JSON mu?)
3. Beklenen veri formatı (UBL-TR XML mi, EDM'nin kendi şeması mı — örnek istenmeli)
4. e-Fatura/e-Arşiv ayrımını kim yapıyor (VKN mükellefiyet sorgusu EDM'de otomatik mi?)
5. Test ortamında gerçek deneme faturası kesilip PDF/yanıt görülebilir mi
6. Fatura iptal/iade akışı (ileride "Satışı Sil" ile bağlantılı olabilir)
7. Rate limit / günlük kota

## Sıradaki Adım

EDM'den yukarıdaki liste alınınca yalnız `efatura/edm_client.py` doldurulur (WSDL ise `zeep`, REST ise `requests` eklenir — `efatura/requirements.txt`'e not düşüldü), `main.py`/DB şeması değişmez. Ayrıca `tenants` tablosundaki fatura alanlarının (unvan/vergi no/vergi dairesi/adres) nereden doldurulacağı netleşmeli (Online Satış kontrol panelinde bir form mu, yoksa elle Supabase Studio'dan mı — henüz karar verilmedi).
