import { existsSync, readdirSync, rmSync } from "node:fs";
import { basename, join } from "node:path";
import { Client, LocalAuth } from "whatsapp-web.js";
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
    "/usr/bin/google-chrome-stable",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
  ]) {
    if (path && existsSync(path)) return path;
  }
  return "/usr/bin/google-chrome-stable";
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

// Confirms the number is reachable before anything is queued against it, so an
// unregistered number is reported as exactly that rather than as a failure deep
// inside the web client. Returns the chat address to send to.
async function accountantAddress(): Promise<string> {
  if (accountantWid) return accountantWid;
  const resolved = await client.getNumberId(ACCOUNTANT_NUMBER);
  if (!resolved) {
    throw new Error(
      `${ACCOUNTANT_NUMBER} has no WhatsApp account, so nothing can be sent to it.`,
    );
  }
  accountantWid = `${ACCOUNTANT_NUMBER}@c.us`;
  console.log(`Accountant ${ACCOUNTANT_NUMBER} is on WhatsApp as ${resolved._serialized}`);
  return accountantWid;
}

// whatsapp-web.js cannot send media against the current WhatsApp Web build: it
// spreads the raw prep model into the outgoing message, so Backbone internals
// (`parent`, `collection`, `_uiObservers`) ride along and WhatsApp's memoizing
// getter is handed an object with no id. Text is unaffected, which is why only
// images failed. This runs WhatsApp's own upload-and-send steps and passes only
// the model's serialized fields, which is the one arrangement that delivers.
async function sendImage(chatId: string, job: Job): Promise<void> {
  const page = (client as unknown as {
    pupPage: {
      evaluate: (
        fn: (arg: {
          chatId: string;
          mime: string;
          data: string;
          filename: string;
          caption: string;
        }) => Promise<string | null>,
        arg: {
          chatId: string;
          mime: string;
          data: string;
          filename: string;
          caption: string;
        },
      ) => Promise<string | null>;
    };
  }).pupPage;

  const failure = await page.evaluate(
    (arg) => {
      const w = globalThis as unknown as Record<string, any>;
      return (async () => {
        try {
          const file = w.WWebJS.mediaInfoToFile({
            mimetype: arg.mime,
            data: arg.data,
            filename: arg.filename,
          });
          const OpaqueData = w.require("WAWebMediaOpaqueData");
          const opaque = await OpaqueData.createFromData(file, arg.mime);
          const media = await w
            .require("WAWebPrepRawMedia")
            .prepRawMedia(opaque, {})
            .waitForPrep();

          const MmsMediaTypes = w.require("WAWebMmsMediaTypes");
          const mediaObject = w
            .require("WAWebMediaStorage")
            .getOrCreateMediaObject(media.filehash);
          const mediaType = MmsMediaTypes.msgToMediaType({
            type: media.type,
            isGif: media.isGif,
            isNewsletter: false,
          });
          if (!(media.mediaBlob instanceof OpaqueData)) {
            media.mediaBlob = await OpaqueData.createFromData(
              media.mediaBlob,
              media.mediaBlob.type,
            );
          }
          media.renderableUrl = media.mediaBlob.url();
          mediaObject.consolidate(media.toJSON());
          media.mediaBlob.autorelease();

          const entry = (
            await w.require("WAWebMediaMmsV4Upload").uploadMedia({
              mimetype: media.mimetype,
              mediaObject,
              mediaType,
            })
          ).mediaEntry;
          if (!entry) return "WhatsApp accepted no media entry for the upload";

          media.set({
            clientUrl: entry.mmsUrl,
            deprecatedMms3Url: entry.deprecatedMms3Url,
            directPath: entry.directPath,
            mediaKey: entry.mediaKey,
            mediaKeyTimestamp: entry.mediaKeyTimestamp,
            filehash: mediaObject.filehash,
            encFilehash: entry.encFilehash,
            uploadhash: entry.uploadHash,
            size: mediaObject.size,
            streamingSidecar: entry.sidecar,
            firstFrameSidecar: entry.firstFrameSidecar,
            mediaHandle: null,
          });

          const chat = await w.WWebJS.getChat(arg.chatId, {
            getAsModel: false,
          });
          if (!chat) return `No chat for ${arg.chatId}`;

          const { getMaybeMeLidUser, getMaybeMePnUser } = w.require(
            "WAWebUserPrefsMeUser",
          );
          const from = chat.id.isLid()
            ? getMaybeMeLidUser()
            : getMaybeMePnUser();
          const MsgKey = w.require("WAWebMsgKey");

          const [msgPromise] = w
            .require("WAWebSendMsgChatAction")
            .addAndSendMsgToChat(chat, {
              id: new MsgKey({
                from,
                to: chat.id,
                id: await MsgKey.newId(),
                participant: undefined,
                selfDir: "out",
              }),
              ack: 0,
              body: media.preview,
              from,
              to: chat.id,
              local: true,
              self: "out",
              t: Math.floor(Date.now() / 1000),
              isNewMsg: true,
              type: "chat",
              ...w
                .require("WAWebGetEphemeralFieldsMsgActionsUtils")
                .getEphemeralFields(chat),
              ...media.toJSON(),
              caption: arg.caption,
            });
          await msgPromise;
          return null;
        } catch (error) {
          return String((error as Error)?.message ?? error);
        }
      })();
    },
    {
      chatId,
      mime: job.mime,
      data: job.data,
      filename: job.filename,
      caption: job.caption,
    },
  );

  if (failure) throw new Error(failure);
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
        await sendImage(await accountantAddress(), job);
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

    // Walks WhatsApp's own media-prep steps one at a time and reports what

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
