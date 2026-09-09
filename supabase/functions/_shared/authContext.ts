import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

export interface AuthContext {
  client: SupabaseClient;
  userId: string;
  tenantId: string;
  role: "owner" | "admin" | "staff";
}

export class AuthError extends Error {
  constructor(message: string, public status: number) {
    super(message);
  }
}

// İstemcinin gönderdiği Authorization header'ı ile kullanıcı-scope'lu bir
// Supabase client kurar (service-role DEĞİL — RLS'e tabi kalır) ve
// `memberships`'ten tenant_id/role'ü çözer. Ana uygulamanın RPC'lerindeki
// (update_tenant_name, update_storefront_image_aspect) rol-kontrolü
// deseninin Edge Function karşılığı.
export async function requireAuthContext(req: Request): Promise<AuthContext> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    throw new AuthError("Oturum bulunamadı.", 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) {
    throw new Error("SUPABASE_URL / SUPABASE_ANON_KEY eksik.");
  }

  const client = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || !userData.user) {
    throw new AuthError("Oturum geçersiz.", 401);
  }

  const { data: membership, error: membershipError } = await client
    .from("memberships")
    .select("tenant_id, role")
    .limit(1)
    .maybeSingle();

  if (membershipError) throw membershipError;
  if (!membership) {
    throw new AuthError("Kiracı bulunamadı.", 403);
  }

  return {
    client,
    userId: userData.user.id,
    tenantId: membership.tenant_id as string,
    role: membership.role as AuthContext["role"],
  };
}

export function requireOwnerOrAdmin(ctx: AuthContext): void {
  if (ctx.role !== "owner" && ctx.role !== "admin") {
    throw new AuthError("Bu işlem için yetkiniz yok.", 403);
  }
}
