"""NicePOS e-Fatura/e-Arşiv gönderim script'i — elle çalıştırılır.

NicePOS (Flutter) "Fatura Kes" butonuyla yalnızca `sale_invoices` tablosuna
bir `pending` satır yazar (bkz. supabase/migrations/0066_sale_invoices.sql).
Bu script o satırları okuyup ilgili satış+kalem+müşteri+kiracı verisini
birleştirir, EDM'ye gönderir (bkz. edm_client.py — henüz stub) ve sonucu
`sale_invoices`'a geri yazar.

Sürekli çalışan bir sunucu DEĞİL — kullanıcı bilgisayarında elle çalıştırır:

    pip install -r efatura/requirements.txt
    python -m efatura.main

Mimari detay: notes/e-fatura-entegrasyonu.md
"""

from __future__ import annotations

import os
from datetime import datetime, timezone

from dotenv import load_dotenv
from supabase import Client, create_client

from efatura import edm_client

load_dotenv()


def _get_client() -> Client:
    url = os.environ["SUPABASE_URL"]
    # ⚠️ service_role key — RLS'i bypass eder, anon key ile KARIŞTIRILMAZ.
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    return create_client(url, key)


def _build_invoice_payload(client: Client, sale_invoice: dict) -> dict:
    sale_id = sale_invoice["sale_id"]

    sale = client.table("sales").select("*").eq("id", sale_id).single().execute().data
    items = client.table("sale_items").select("*").eq("sale_id", sale_id).execute().data
    tenant = (
        client.table("tenants").select("*").eq("id", sale_invoice["tenant_id"]).single().execute().data
    )
    customer = None
    if sale.get("customer_id"):
        customer = (
            client.table("customers").select("*").eq("id", sale["customer_id"]).single().execute().data
        )

    return {
        "invoice_type": sale_invoice["invoice_type"],
        "sale": sale,
        "items": items,
        "tenant": tenant,
        "customer": customer,
    }


def _process_one(client: Client, sale_invoice: dict) -> None:
    invoice_id = sale_invoice["id"]
    try:
        payload = _build_invoice_payload(client, sale_invoice)
        result = edm_client.send_invoice(payload)
        client.table("sale_invoices").update(
            {
                "status": "sent",
                "edm_invoice_id": result.edm_invoice_id,
                "pdf_url": result.pdf_url,
                "completed_at": datetime.now(timezone.utc).isoformat(),
            }
        ).eq("id", invoice_id).execute()
        print(f"[OK] {sale_invoice['sale_id']} -> {result.edm_invoice_id}")
    except Exception as exc:  # noqa: BLE001 — her hata türü failed'e düşer, kullanıcı Bekleyenler'den görür
        client.table("sale_invoices").update(
            {
                "status": "failed",
                "error_message": str(exc),
                "completed_at": datetime.now(timezone.utc).isoformat(),
            }
        ).eq("id", invoice_id).execute()
        print(f"[FAILED] {sale_invoice['sale_id']} -> {exc}")


def main() -> None:
    client = _get_client()
    pending = (
        client.table("sale_invoices").select("*").eq("status", "pending").execute().data
    )
    if not pending:
        print("Bekleyen fatura talebi yok.")
        return

    print(f"{len(pending)} bekleyen fatura talebi bulundu.")
    for sale_invoice in pending:
        _process_one(client, sale_invoice)


if __name__ == "__main__":
    main()
