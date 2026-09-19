import { existsSync, readdirSync, rmSync } from "node:fs";
import { basename, join } from "node:path";
import { Client, LocalAuth, MessageMedia } from "whatsapp-web.js";
import QRCode from "qrcode";
import qrcodeTerminal from "qrcode-terminal";

const AUTH_PATH = "./.wwebjs_auth";
const PORT = Number(Bun.env.PORT ?? 5555);
const DESK_ENV = (Bun.env.DESK_ENV ?? "dev").trim().toLowerCase() === "prod"
  ? "prod"
  : "dev";
const ACCOUNTANT_NUMBER = DESK_ENV === "prod" ? "972546850133" : "97289267927";
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
let sentCount = 0;
let failedCount = 0;
let lastError: string | null = null;
let accountantWid: string | null = null;

// WhatsApp addresses a chat by its own id, and guessing it as `<digits>@c.us`
// silently produces an address that resolves to nothing when the number has no
// WhatsApp account — sendMessage then dies deep inside the web client with an
// error that names neither the number nor the cause. Ask WhatsApp to resolve
// it instead, so an unreachable number is reported as exactly that.
async function accountantAddress(): Promise<string> {
  if (accountantWid) return accountantWid;
  const resolved = await client.getNumberId(ACCOUNTANT_NUMBER);
  if (!resolved) {
    throw new Error(
      `${ACCOUNTANT_NUMBER} has no WhatsApp account, so nothing can be sent to it.`,
    );
  }
  accountantWid = resolved._serialized;
  console.log(`Accountant resolved to ${accountantWid}`);
  return accountantWid;
}

// A redeploy kills the container outright, so Chromium never releases the
// profile lock it keeps on the session volume and the next boot refuses to
// launch. Only one desk ever runs against this volume, so any lock found at
// startup belongs to a process that is already gone.
function clearStaleProfileLocks(): void {
  if (!existsSync(AUTH_PATH)) return;
  let entries: string[];
  try {
    entries = readdirSync(AUTH_PATH, { recursive: true }) as string[];
  } catch {
    return;
  }
  for (const entry of entries) {
    if (!basename(entry).startsWith("Singleton")) continue;
    try {
      rmSync(join(AUTH_PATH, entry), { force: true });
      console.log(`Cleared stale profile lock: ${entry}`);
    } catch {
      // Leave it: Chromium's own launch error says more than we could here.
    }
  }
}

clearStaleProfileLocks();

const client = new Client({
  authStrategy: new LocalAuth({ dataPath: AUTH_PATH }),
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
  accountantWid = null;
  console.log(`WhatsApp ready. ${DESK_ENV} slips go to ${ACCOUNTANT_NUMBER}`);
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
      // One bad slip must not discard the ones queued behind it: the phone has
      // already been told the whole batch was accepted.
      try {
        const media = new MessageMedia(job.mime, job.data, job.filename);
        await client.sendMessage(await accountantAddress(), media, {
          caption: job.caption,
        });
        lastSentAt = Date.now();
        sentCount += 1;
        console.log(`Sent ${job.filename} (${queue.length} waiting)`);
      } catch (error) {
        failedCount += 1;
        lastError = error instanceof Error ? error.message : String(error);
        console.error(`Send failed for ${job.filename}: ${lastError}`);
      }
    }
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

// WhatsApp has moved these numbers to `@lid` addressing, which the web client
// resolves inconsistently: some call paths hand back a chat model with no id
// and the send dies on a memoizing getter. Try each way of reaching the chat
// and report which one actually delivers, so the sender can use that one.
async function diagnose(): Promise<unknown> {
  const results: Array<Record<string, unknown>> = [];
  const attempt = async (strategy: string, run: () => Promise<string>) => {
    try {
      results.push({ strategy, ok: true, detail: await run() });
    } catch (error) {
      const text = error instanceof Error ? error.message : String(error);
      results.push({ strategy, ok: false, error: text.split("\n")[0] });
    }
  };

  const cus = `${ACCOUNTANT_NUMBER}@c.us`;
  const lid = (await client.getNumberId(ACCOUNTANT_NUMBER))?._serialized ?? null;

  await attempt("getChatById(@c.us)", async () => {
    const chat = await client.getChatById(cus);
    return chat?.id?._serialized ?? "no id";
  });
  await attempt("client.sendMessage(@c.us)", async () => {
    const msg = await client.sendMessage(cus, "desk diag: c.us direct");
    return msg?.id?._serialized ?? "sent";
  });
  await attempt("chat(@c.us).sendMessage", async () => {
    const chat = await client.getChatById(cus);
    const msg = await chat.sendMessage("desk diag: c.us via chat");
    return msg?.id?._serialized ?? "sent";
  });

  if (lid) {
    await attempt("getChatById(@lid)", async () => {
      const chat = await client.getChatById(lid);
      return chat?.id?._serialized ?? "no id";
    });
    await attempt("client.sendMessage(@lid)", async () => {
      const msg = await client.sendMessage(lid, "desk diag: lid direct");
      return msg?.id?._serialized ?? "sent";
    });
    await attempt("chat(@lid).sendMessage", async () => {
      const chat = await client.getChatById(lid);
      const msg = await chat.sendMessage("desk diag: lid via chat");
      return msg?.id?._serialized ?? "sent";
    });
  }

  return { number: ACCOUNTANT_NUMBER, lid, results };
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
        accountant: ACCOUNTANT_NUMBER,
        resolved: accountantWid,
        sent: sentCount,
        failed: failedCount,
        lastError,
      });
    }

    // Answers the only question worth asking when nothing arrives: does the
    // target number actually have a WhatsApp account?
    if (pathname === "/check") {
      if (!ready) {
        return Response.json(
          { error: "WhatsApp is not connected" },
          { status: 503 },
        );
      }
      const asked = new URL(req.url).searchParams.get("number")
        ?? ACCOUNTANT_NUMBER;
      const digits = asked.replace(/\D/g, "");
      const found = await client.getNumberId(digits);
      return Response.json({
        number: digits,
        onWhatsApp: found != null,
        wid: found?._serialized ?? null,
      });
    }

    if (pathname === "/diag") {
      if (!ready) {
        return Response.json(
          { error: "WhatsApp is not connected" },
          { status: 503 },
        );
      }
      return Response.json(await diagnose());
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
