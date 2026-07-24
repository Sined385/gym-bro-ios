#!/usr/bin/env node
// Fills missing `uk` translations in every Localizable.xcstrings via
// OpenAI, marking them "needs_review" for human pass-through.
//
//   OPENAI_API_KEY=... node scripts/translate_xcstrings.mjs
//   (falls back to reading ../gym-bro-api/.env)
//
// Idempotent: keys that already have a uk stringUnit are skipped.

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import path from "node:path";

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const CATALOGS = [
  "GymBro/Localizable.xcstrings",
  "GymJamWatch/Localizable.xcstrings",
  "GymJamWidgets/Localizable.xcstrings",
];
const BATCH = 40;

function apiKey() {
  if (process.env.OPENAI_API_KEY) return process.env.OPENAI_API_KEY;
  const envPath = path.join(ROOT, "..", "gym-bro-api", ".env");
  if (existsSync(envPath)) {
    const m = readFileSync(envPath, "utf8").match(/^OPENAI_API_KEY="?([^"\n]+)"?/m);
    if (m) return m[1];
  }
  throw new Error("OPENAI_API_KEY not found");
}

async function translateBatch(keys) {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o",
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            "You translate UI strings for GymJam, a gym workout-tracking iOS app, from English to Ukrainian. " +
            "Fitness register: use natural Ukrainian gym terminology (підхід for set, повторення for rep, тренування for workout/session, розминка for warm-up). " +
            "Keep translations concise — these are buttons, labels and short card texts; match the source's capitalization style (ALL-CAPS stays ALL-CAPS). " +
            "Never translate: the app name GymJam, placeholders like %@ %lld %d, SF Symbol names, or anything that looks like an identifier. " +
            'Return a JSON object mapping each input string EXACTLY as given to its Ukrainian translation: {"translations": {"<en>": "<uk>", ...}}',
        },
        { role: "user", content: JSON.stringify(keys) },
      ],
    }),
  });
  if (!res.ok) throw new Error(`OpenAI ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return JSON.parse(data.choices[0].message.content).translations;
}

for (const rel of CATALOGS) {
  const catalogPath = path.join(ROOT, rel);
  const catalog = JSON.parse(readFileSync(catalogPath, "utf8"));
  const missing = Object.entries(catalog.strings).filter(
    ([, v]) => !v?.localizations?.uk?.stringUnit?.value,
  );
  console.log(`${rel}: ${missing.length} keys need uk`);

  for (let i = 0; i < missing.length; i += BATCH) {
    const slice = missing.slice(i, i + BATCH).map(([k]) => k);
    const translations = await translateBatch(slice);
    for (const key of slice) {
      const uk = translations[key];
      if (!uk) {
        console.warn(`  ! no translation returned for: ${key.slice(0, 60)}`);
        continue;
      }
      catalog.strings[key] ??= {};
      catalog.strings[key].localizations ??= {};
      catalog.strings[key].localizations.uk = {
        stringUnit: { state: "needs_review", value: uk },
      };
    }
    writeFileSync(catalogPath, JSON.stringify(catalog, null, 2) + "\n");
    console.log(`  batch ${i / BATCH + 1}/${Math.ceil(missing.length / BATCH)} written`);
  }
}
console.log("Done.");
