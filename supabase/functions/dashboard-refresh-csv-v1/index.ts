import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// FWIOS legacy dashboard feed retired 2026-10-23.
// No database queries or portfolio-data output are permitted.
Deno.serve((_req: Request) => new Response("Legacy Dashboard endpoint retired", {
  status: 410,
  headers: {
    "content-type": "text/plain; charset=utf-8",
    "cache-control": "no-store"
  }
}));
