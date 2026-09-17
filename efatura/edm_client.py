"""EDM Bilişim e-Fatura/e-Arşiv API istemcisi — İSKELET.

EDM'nin API bilgileri (kullanıcı adı/şifre, test/canlı ortam endpoint'leri,
WSDL/SOAP mu REST/JSON mu, beklenen veri formatı) henüz alınmadı. Bu dosya,
o bilgiler gelene kadar akışın geri kalanının (main.py) test edilebilmesi için
NotImplementedError fırlatan bir stub'tır.

EDM'den istenmesi gereken somut liste ve akışın genel mimarisi için bkz.
notes/e-fatura-entegrasyonu.md.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class InvoiceResult:
    edm_invoice_id: str
    pdf_url: str | None = None


def send_invoice(payload: dict) -> InvoiceResult:
    """`payload` — main.py'nin bir araya getirdiği satış+kalem+müşteri+kiracı
    verisi (bkz. main.py `_build_invoice_payload`). EDM API bilgisi gelince
    burası WSDL/SOAP (`zeep`) veya REST (`requests`) çağrısıyla doldurulur ve
    başarılı sonuçta `InvoiceResult` döner; EDM bir hata döndürürse burada
    (veya çağıran main.py'de) bir exception fırlatılır ve `sale_invoices`
    satırı `failed` + `error_message` olarak güncellenir.
    """
    raise NotImplementedError(
        "EDM API bilgisi bekleniyor (kullanıcı adı/şifre, endpoint, format) — "
        "bkz. notes/e-fatura-entegrasyonu.md. Bu fonksiyon doldurulunca "
        "main.py'de başka bir değişiklik gerekmez."
    )
