// purge_files: menghapus file storage yang sudah diantrekan di file_delete_queue.
// Dipicu pg_cron (tiap jam) lewat public.invoke_edge('purge_files').
// Auth: header x-wts-secret (verify_jwt = false di config.toml).
import { createClient } from "jsr:@supabase/supabase-js@2";

const SECRET = Deno.env.get("EDGE_SHARED_SECRET")!;
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

type Row = { id: number; bucket: string; path: string; attempts: number };
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.headers.get("x-wts-secret") !== SECRET) return json({ error: "forbidden" }, 403);

  let deleted = 0, failed = 0, dropped = 0;
  for (let round = 0; round < 5; round++) {           // maks 5 x 200 file per eksekusi
    const { data, error } = await db.from("file_delete_queue")
      .select("id,bucket,path,attempts").lt("attempts", 5).order("id").limit(200);
    if (error) return json({ error: error.message }, 500);
    const rows = (data ?? []) as Row[];
    if (rows.length === 0) break;

    const byBucket = new Map<string, Row[]>();
    for (const r of rows) byBucket.set(r.bucket, [...(byBucket.get(r.bucket) ?? []), r]);

    for (const [bucket, items] of byBucket) {
      const { error: e } = await db.storage.from(bucket).remove(items.map((i) => i.path));
      if (e) {
        failed += items.length;
        for (const i of items) {
          await db.from("file_delete_queue").update({ attempts: i.attempts + 1 }).eq("id", i.id);
        }
      } else {
        deleted += items.length;     // remove() sukses juga bila file sudah tidak ada
        await db.from("file_delete_queue").delete().in("id", items.map((i) => i.id));
      }
    }
  }

  // Item yang gagal 5x dicatat ke audit_logs lalu dibuang agar antrean tidak macet
  const { data: dead } = await db.from("file_delete_queue").select("id,bucket,path").gte("attempts", 5).limit(100);
  if (dead?.length) {
    await db.from("audit_logs").insert(dead.map((d) => ({
      action: "purge_failed", target_type: "file", target_id: `${d.bucket}/${d.path}`,
    })));
    await db.from("file_delete_queue").delete().in("id", dead.map((d) => d.id));
    dropped = dead.length;
  }
  return json({ deleted, failed, dropped });
});
