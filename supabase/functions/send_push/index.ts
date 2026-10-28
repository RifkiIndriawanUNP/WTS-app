// send_push: mengirim push FCM untuk satu baris notifications.
// Dipicu trigger DB (trg_push_notification) lewat pg_net. Isi pesan chat TIDAK dikirim di push.
// Secrets: EDGE_SHARED_SECRET, FCM_SERVICE_ACCOUNT (JSON service account Firebase).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const SECRET = Deno.env.get("EDGE_SHARED_SECRET")!;
const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const TEXT: Record<string, [string, string]> = {
  comment: ["Komentar baru", "Ada komentar di postinganmu"],
  reply: ["Balasan baru", "Seseorang membalas komentarmu"],
  message: ["Pesan baru", "Kamu punya pesan baru"],
  market_new_chat: ["Ada yang tertarik", "Seseorang menghubungi produkmu"],
  market_offer: ["Tawaran baru", "Ada tawaran harga baru"],
  market_offer_rejected: ["Tawaran ditolak", "Tawaranmu ditolak"],
  market_agreed: ["Harga disepakati", "Atur titik temu COD sekarang"],
  market_progress: ["Update transaksi", "Status transaksi diperbarui"],
  market_sold: ["Transaksi selesai", "Barang ditandai terjual"],
  market_cancelled: ["Transaksi dibatalkan", "Lawan transaksi membatalkan"],
  product_sold: ["Produk terjual", "Produk yang kamu minati sudah terjual"],
  product_expiring: ["Produkmu akan hilang", "Perpanjang agar tetap tampil"],
  post_expiring: ["Postinganmu akan hilang", "Postinganmu segera berakhir"],
  moderation: ["Pemberitahuan moderasi", "Ada tindakan moderasi pada kontenmu"],
  account_inactive_warning: ["Akun akan dihapus", "Login untuk mempertahankan akunmu"],
};

let cached: { token: string; exp: number } | null = null;
async function accessToken(): Promise<string> {
  if (cached && cached.exp > Date.now() + 60_000) return cached.token;
  const key = await importPKCS8(sa.private_key, "RS256");
  const jwt = await new SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email).setSubject(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt().setExpirationTime("1h").sign(key);
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  const j = await r.json();
  cached = { token: j.access_token, exp: Date.now() + (j.expires_in ?? 3600) * 1000 };
  return cached.token;
}

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.headers.get("x-wts-secret") !== SECRET) return json({ error: "forbidden" }, 403);
  const { notification_id } = await req.json();

  const { data: n } = await db.from("notifications")
    .select("id,user_id,type,payload,pushed_at").eq("id", notification_id).maybeSingle();
  if (!n || n.pushed_at) return json({ skipped: true });

  const markDone = () => db.from("notifications").update({ pushed_at: new Date().toISOString() }).eq("id", n.id);

  const { data: prof } = await db.from("profiles").select("notif_prefs,status").eq("id", n.user_id).maybeSingle();
  if (!prof || prof.status === "banned" || prof.notif_prefs?.[n.type] === false) {
    await markDone();
    return json({ skipped: "prefs" });
  }

  const { data: tokens } = await db.from("device_tokens").select("id,fcm_token").eq("user_id", n.user_id);
  if (!tokens?.length) { await markDone(); return json({ sent: 0 }); }

  const [title, body] = TEXT[n.type] ?? ["WTS", "Ada pemberitahuan baru"];
  const data = Object.fromEntries(
    Object.entries({ type: n.type, notification_id: n.id, ...(n.payload ?? {}) }).map(([k, v]) => [k, String(v)]),
  );
  const at = await accessToken();
  let sent = 0;
  await Promise.all(tokens.map(async (t) => {
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: { token: t.fcm_token, notification: { title, body }, data } }),
    });
    if (r.ok) { sent++; return; }
    const err = await r.json().catch(() => ({}));
    const code = err?.error?.details?.[0]?.errorCode ?? err?.error?.status;
    if (code === "UNREGISTERED" || code === "INVALID_ARGUMENT" || code === "NOT_FOUND") {
      await db.from("device_tokens").delete().eq("id", t.id);      // bersihkan token mati
    }
  }));
  await markDone();
  return json({ sent });
});
