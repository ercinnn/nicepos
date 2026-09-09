// Cloudflare Registrar API (beta, Nisan 2026) + Pages/DNS API sarmalayıcısı.
//
// ⚠️ Endpoint yolları bu API beta olduğundan ve tam dokümantasyona bu turda
// erişilemediğinden EN İYİ TAHMİN üzerine yazıldı (Cloudflare'in genel hesap
// kapsamlı kaynak deseni: `/accounts/{account_id}/registrar/...`). Aşama B'de
// (kullanıcının gerçek Cloudflare Registrar hesabı+token'ı hazır olduğunda)
// https://developers.cloudflare.com/registrar/registrar-api/ 'a karşı
// doğrulanıp gerekirse düzeltilmeli — bkz. plan dosyası §8.
//
// ⚠️ TLD allowlist (v1 kararı): yalnız .com/.net/.org — .com.tr gibi ek
// kimlik/vergi no gerektiren uzantılar bu turun kapsamı DIŞINDA.
export const ALLOWED_TLDS = ["com", "net", "org"] as const;

export function isAllowedDomain(domain: string): boolean {
  const tld = domain.trim().toLowerCase().split(".").pop();
  return !!tld && (ALLOWED_TLDS as readonly string[]).includes(tld);
}

export interface DomainCandidate {
  domain: string;
  available: boolean;
  priceAmount: number;
  priceCurrency: string;
}

export interface RegistrantContact {
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  address: string;
  city: string;
  country: string;
  zipCode?: string;
}

export interface RegistrationResult {
  registrationId: string;
  status: string;
}

export interface RegistrationStatusResult {
  status: string; // ör. "pending" | "complete" | "error"
  zoneId?: string;
}

export interface CloudflareClient {
  searchDomains(query: string): Promise<DomainCandidate[]>;
  checkDomains(domains: string[]): Promise<DomainCandidate[]>;
  registerDomain(
    domain: string,
    contact: RegistrantContact,
  ): Promise<RegistrationResult>;
  getRegistrationStatus(domain: string): Promise<RegistrationStatusResult>;
  createCnameRecord(zoneId: string, target: string): Promise<string>;
  addPagesCustomDomain(domain: string): Promise<{ status: string }>;
}

const CF_API_BASE = "https://api.cloudflare.com/client/v4";
const PAGES_PROJECT_NAME = "nicepos-online-satis";
const PAGES_TARGET_HOST = "nicepos-online-satis.pages.dev";

class RealCloudflareClient implements CloudflareClient {
  constructor(private accountId: string, private apiToken: string) {}

  private async request<T>(
    path: string,
    init: RequestInit = {},
  ): Promise<T> {
    const res = await fetch(`${CF_API_BASE}${path}`, {
      ...init,
      headers: {
        Authorization: `Bearer ${this.apiToken}`,
        "Content-Type": "application/json",
        ...(init.headers ?? {}),
      },
    });
    const body = await res.json();
    if (!res.ok || body.success === false) {
      throw new Error(
        `Cloudflare API hatası (${path}): ${JSON.stringify(body.errors ?? body)}`,
      );
    }
    return body.result as T;
  }

  // Gerçek Cloudflare şeması (2026-08-31'de canlı hesapla doğrulandı — beta
  // dokümantasyonu erişilemediğinden ÖNCEKİ sürüm tahminiydi, YANLIŞ çıktı):
  //   GET .../domain-search?q=<terim>  (parametre adı `query` DEĞİL `q`)
  //     → { domains: [{ name, registrable, tier, pricing?: { currency,
  //         registration_cost, renewal_cost } }] }
  //     — yalnız MÜSAİT adaylar döner (alınmış olan sorgu teriminin kendisi
  //     hiç listede ÇIKMAZ, `available:false` olarak da GÖSTERİLMEZ).
  //   POST .../domain-check  body {domains:[...]}
  //     → aynı şekil, MÜSAİT DEĞİLSE `reason` alanı (ör. "domain_unavailable")
  //     dolu gelir, `pricing` YOK; müsaitse `pricing` dolu, `reason` yok.
  private mapDomainResult(r: {
    name: string;
    registrable: boolean;
    pricing?: { currency: string; registration_cost: string };
  }): DomainCandidate {
    return {
      domain: r.name,
      available: r.registrable,
      priceAmount: r.pricing ? Number(r.pricing.registration_cost) : 0,
      priceCurrency: r.pricing?.currency ?? "USD",
    };
  }

  async searchDomains(query: string): Promise<DomainCandidate[]> {
    const result = await this.request<{
      domains: {
        name: string;
        registrable: boolean;
        pricing?: { currency: string; registration_cost: string };
      }[];
    }>(
      `/accounts/${this.accountId}/registrar/domain-search?q=${encodeURIComponent(query)}`,
    );
    return result.domains
      .filter((r) => isAllowedDomain(r.name))
      .map((r) => this.mapDomainResult(r));
  }

  async checkDomains(domains: string[]): Promise<DomainCandidate[]> {
    const filtered = domains.filter(isAllowedDomain);
    if (filtered.length === 0) return [];
    const result = await this.request<{
      domains: {
        name: string;
        registrable: boolean;
        pricing?: { currency: string; registration_cost: string };
      }[];
    }>(`/accounts/${this.accountId}/registrar/domain-check`, {
      method: "POST",
      body: JSON.stringify({ domains: filtered }),
    });
    return result.domains.map((r) => this.mapDomainResult(r));
  }

  async registerDomain(
    domain: string,
    contact: RegistrantContact,
  ): Promise<RegistrationResult> {
    if (!isAllowedDomain(domain)) {
      throw new Error(`Desteklenmeyen uzantı: ${domain}`);
    }
    const result = await this.request<{ id: string; status: string }>(
      `/accounts/${this.accountId}/registrar/registrations`,
      {
        method: "POST",
        body: JSON.stringify({ domain, registrant: contact }),
      },
    );
    return { registrationId: result.id, status: result.status };
  }

  async getRegistrationStatus(
    domain: string,
  ): Promise<RegistrationStatusResult> {
    const result = await this.request<{ status: string; zone_id?: string }>(
      `/accounts/${this.accountId}/registrar/registrations/${domain}/registration-status`,
    );
    return { status: result.status, zoneId: result.zone_id };
  }

  async createCnameRecord(zoneId: string, target: string): Promise<string> {
    const result = await this.request<{ id: string }>(
      `/zones/${zoneId}/dns_records`,
      {
        method: "POST",
        body: JSON.stringify({
          type: "CNAME",
          name: "@",
          content: target,
          proxied: true,
        }),
      },
    );
    return result.id;
  }

  async addPagesCustomDomain(domain: string): Promise<{ status: string }> {
    const result = await this.request<{ status: string }>(
      `/accounts/${this.accountId}/pages/projects/${PAGES_PROJECT_NAME}/domains`,
      { method: "POST", body: JSON.stringify({ name: domain }) },
    );
    return { status: result.status };
  }
}

// Aşama A (bugün): gerçek Cloudflare Registrar hesabı/token'ı henüz yok —
// bu mock, arama/kontrol/kayıt/DNS/Pages akışının TAMAMINI (paid→registering
// →registered→connecting_dns→connected geçişleri dahil) gerçek Cloudflare'e
// dokunmadan test etmeyi sağlar. `CLOUDFLARE_API_TOKEN` secret'ı set
// edilmediği sürece bu kullanılır — token set edilince otomatik gerçek
// client'a geçilir (bkz. getCloudflareClient()).
class MockCloudflareClient implements CloudflareClient {
  async searchDomains(query: string): Promise<DomainCandidate[]> {
    const base = query.trim().toLowerCase().replace(/[^a-z0-9-]/g, "");
    if (!base) return [];
    return ALLOWED_TLDS.map((tld, i) => ({
      domain: `${base}.${tld}`,
      available: i !== 1, // ikinci sonucu "dolu" göstererek UI'da her iki durumu da test eder
      priceAmount: 12.5 + i * 3,
      priceCurrency: "USD",
    }));
  }

  async checkDomains(domains: string[]): Promise<DomainCandidate[]> {
    return domains.filter(isAllowedDomain).map((domain) => ({
      domain,
      available: true,
      priceAmount: 12.5,
      priceCurrency: "USD",
    }));
  }

  async registerDomain(domain: string): Promise<RegistrationResult> {
    return { registrationId: `mock-reg-${domain}-${Date.now()}`, status: "pending" };
  }

  async getRegistrationStatus(
    domain: string,
  ): Promise<RegistrationStatusResult> {
    // Mock'ta ilk sorguda hep "complete" döner (poll fonksiyonunu senkron
    // test edebilmek için) — gerçek entegrasyonda birkaç poll döngüsü sürer.
    return { status: "complete", zoneId: `mock-zone-${domain}` };
  }

  async createCnameRecord(_zoneId: string, _target: string): Promise<string> {
    return `mock-dns-record-${Date.now()}`;
  }

  async addPagesCustomDomain(_domain: string): Promise<{ status: string }> {
    return { status: "active" };
  }
}

export function getCloudflareClient(): CloudflareClient {
  const accountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID");
  const apiToken = Deno.env.get("CLOUDFLARE_API_TOKEN");
  if (!accountId || !apiToken) {
    return new MockCloudflareClient();
  }
  return new RealCloudflareClient(accountId, apiToken);
}

export const PAGES_TARGET = PAGES_TARGET_HOST;
