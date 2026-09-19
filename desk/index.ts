import { existsSync } from "node:fs";
import { Client, LocalAuth, MessageMedia } from "whatsapp-web.js";
import QRCode from "qrcode";
import qrcodeTerminal from "qrcode-terminal";

const PORT = Number(Bun.env.PORT ?? 5555);
const DESK_ENV = (Bun.env.DESK_ENV ?? "dev").trim().toLowerCase() === "prod"
  ? "prod"
  : "dev";
const ACCOUNTANT =
  DESK_ENV === "prod" ? "972546850133@c.us" : "97289267927@c.us";
const GAP_MS = 20_000;
const CHROMIUM = (() => {
  for (const path of [
    Bun.env.CHROMIUM_PATH,
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
  ]) {
    if (path && existsSync(path)) return path;
  }
  return "/usr/bin/chromium";
})();

type Job = {
  mime: string;
  data: string;
  filename: string;
  caption: string;
};

const queue: Job[] = [];
let pumping = false;
let lastSentAt = 0;
let ready = false;
let latestQr: string | null = null;

const client = new Client({
  authStrategy: new LocalAuth({ dataPath: "./.wwebjs_auth" }),
  puppeteer: {
    headless: true,
    executablePath: CHROMIUM,
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu",
    ],
  },
});

client.on("qr", (qr) => {
  ready = false;
  latestQr = qr;
  console.log("Scan this QR with WhatsApp → Linked devices:");
  qrcodeTerminal.generate(qr, { small: true });
});

client.on("ready", () => {
  ready = true;
  latestQr = null;
  console.log(`WhatsApp ready. ${DESK_ENV} slips go to ${ACCOUNTANT}`);
  void pump();
});

client.on("disconnected", (reason) => {
  ready = false;
  console.log("WhatsApp disconnected:", reason);
});

client.on("auth_failure", (message) => {
  ready = false;
  console.error("WhatsApp auth failed:", message);
});

await client.initialize();

async function pump(): Promise<void> {
  if (pumping) return;
  pumping = true;
  try {
    while (queue.length > 0) {
      if (!ready) {
        await Bun.sleep(1000);
        continue;
      }
      const wait = lastSentAt + GAP_MS - Date.now();
      if (lastSentAt > 0 && wait > 0) await Bun.sleep(wait);
      const job = queue.shift();
      if (!job) break;
      const media = new MessageMedia(job.mime, job.data, job.filename);
      await client.sendMessage(ACCOUNTANT, media, { caption: job.caption });
      lastSentAt = Date.now();
      console.log(`Sent ${job.filename} (${queue.length} waiting)`);
    }
  } catch (error) {
    console.error("Send failed:", error);
  } finally {
    pumping = false;
    if (queue.length > 0 && ready) void pump();
  }
}

function captionsFor(form: Awaited<ReturnType<Request["formData"]>>, count: number): string[] {
  const raw = form.get("captions");
  if (typeof raw === "string" && raw.trim().startsWith("[")) {
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (Array.isArray(parsed)) {
        return parsed.map((value) => String(value ?? ""));
      }
    } catch {
      // Fall through to one-caption-per-file.
    }
  }
  const many = form.getAll("captions");
  return Array.from({ length: count }, (_, i) => {
    const value = many[i];
    return typeof value === "string" ? value : "";
  });
}

async function asJobs(form: Awaited<ReturnType<Request["formData"]>>): Promise<Job[]> {
  const files = form.getAll("receipts");
  const captions = captionsFor(form, files.length);
  const jobs: Job[] = [];
  for (let i = 0; i < files.length; i++) {
    const file = files[i];
    if (typeof file === "string" || file == null) continue;
    if (!("arrayBuffer" in file)) continue;
    const blob = file as Blob & { name?: string; type?: string };
    const given = captions[i]?.trim() ?? "";
    const filename = blob.name || `receipt-${i + 1}.jpg`;
    const bytes = await blob.arrayBuffer();
    jobs.push({
      mime: blob.type || "image/jpeg",
      data: Buffer.from(bytes).toString("base64"),
      filename,
      caption: given.length > 0 ? given : filename,
    });
  }
  return jobs;
}

const server = Bun.serve({
  port: PORT,
  maxRequestBodySize: 32 * 1024 * 1024,
  async fetch(req) {
    const { pathname } = new URL(req.url);

    if (pathname === "/health") {
      return new Response("ok");
    }

    if (pathname === "/status") {
      return Response.json({
        ready,
        queued: queue.length,
        env: DESK_ENV,
        accountant: ACCOUNTANT,
      });
    }

    if (pathname === "/qr") {
      if (ready) return new Response(null, { status: 204 });
      if (!latestQr) {
        return Response.json(
          { error: "Waiting for a QR from WhatsApp" },
          { status: 503 },
        );
      }
      const png = await QRCode.toBuffer(latestQr, {
        type: "png",
        width: 360,
        margin: 1,
      });
      return new Response(png, { headers: { "Content-Type": "image/png" } });
    }

    if (pathname === "/transmit") {
      if (req.method !== "POST") {
        return Response.json({ error: "Method not allowed" }, { status: 405 });
      }
      if (!ready) {
        return Response.json(
          { error: "WhatsApp is not connected" },
          { status: 503 },
        );
      }
      let jobs: Job[];
      try {
        jobs = await asJobs(await req.formData());
      } catch {
        return Response.json({ error: "Expected multipart form" }, { status: 400 });
      }
      if (jobs.length === 0) {
        return Response.json({ error: "No receipt images" }, { status: 400 });
      }
      queue.push(...jobs);
      void pump();
      return Response.json({ accepted: jobs.length, queued: queue.length }, { status: 202 });
    }

    return new Response("Not found", { status: 404 });
  },
});

console.log(`Accountant desk on ${server.url} (${DESK_ENV})`);
