#!/usr/bin/env node
// Extracts SwiftUI LocalizedStringKey-position literals + String(localized:)
// keys from Swift sources into each target's Localizable.xcstrings.
//
//   node scripts/extract_strings.mjs
//
// Why not xcodebuild? `build` never writes catalogs back from the CLI,
// and `-exportLocalizations` insists on building every target for every
// platform (fails on SwiftyGif-macOS and WatchKit-on-iOS). This scanner
// is deterministic and reviewable instead.
//
// Interpolated literals ("Step \(x) of \(y)") are NOT auto-extracted —
// their runtime keys are format strings ("Step %lld of %lld") that the
// scanner can't derive reliably. They're written to
// build/interpolated-strings-report.txt for manual conversion.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { execSync } from "node:child_process";
import path from "node:path";

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");

const TARGETS = [
  { dir: "GymBro", catalog: "GymBro/Localizable.xcstrings" },
  { dir: "GymJamWatch", catalog: "GymJamWatch/Localizable.xcstrings" },
  { dir: "GymJamWidgets", catalog: "GymJamWidgets/Localizable.xcstrings" },
];

// SwiftUI initializers/modifiers whose first string literal argument is a
// LocalizedStringKey (auto-localized at runtime once a catalog exists).
const CALL_PATTERNS = [
  "Text",
  "Button",
  "Label",
  "TextField",
  "SecureField",
  "Toggle",
  "Picker",
  "Section",
  "Link",
  "Menu",
  "ProgressView",
  "LabeledContent",
];
const MODIFIER_PATTERNS = [
  "navigationTitle",
  "alert",
  "confirmationDialog",
];

// String literal WITHOUT interpolation: no \( inside.
const literal = String.raw`"((?:[^"\\]|\\[^(])*)"`;
const callRe = new RegExp(
  String.raw`(?:\b(?:${CALL_PATTERNS.join("|")})\(|\.(?:${MODIFIER_PATTERNS.join("|")})\()\s*${literal}`,
  "g",
);
const localizedRe = new RegExp(
  String.raw`String\(\s*localized:\s*${literal}`,
  "g",
);
const interpolatedRe = new RegExp(
  String.raw`\b(?:${CALL_PATTERNS.join("|")})\(\s*"(?:[^"\\]|\\.)*\\\((?:[^"\\]|\\.)*"`,
  "g",
);

function swiftFiles(dir) {
  const out = execSync(`find ${JSON.stringify(path.join(ROOT, dir))} -name '*.swift'`, {
    encoding: "utf8",
  });
  return out.split("\n").filter(Boolean);
}

function unescape(s) {
  return s
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "\t")
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, "\\")
    .replace(/\\u\{([0-9a-fA-F]+)\}/g, (_, hex) =>
      String.fromCodePoint(parseInt(hex, 16)),
    );
}

const interpolatedReport = [];

for (const target of TARGETS) {
  const catalogPath = path.join(ROOT, target.catalog);
  const catalog = JSON.parse(readFileSync(catalogPath, "utf8"));
  catalog.strings ??= {};
  let added = 0;

  for (const file of swiftFiles(target.dir)) {
    const src = readFileSync(file, "utf8");
    // Skip preview providers' sample data? Keep simple: extract all.
    for (const re of [callRe, localizedRe]) {
      re.lastIndex = 0;
      let m;
      while ((m = re.exec(src)) !== null) {
        const key = unescape(m[1]);
        if (!key.trim()) continue;
        if (/^[\d\s.,:%×+\-–—\/#]*$/.test(key)) continue; // pure numbers/punct
        if (!(key in catalog.strings)) {
          catalog.strings[key] = {};
          added++;
        }
      }
    }
    interpolatedRe.lastIndex = 0;
    let mi;
    while ((mi = interpolatedRe.exec(src)) !== null) {
      interpolatedReport.push(`${path.relative(ROOT, file)}: ${mi[0].slice(0, 120)}`);
    }
  }

  writeFileSync(catalogPath, JSON.stringify(catalog, null, 2) + "\n");
  console.log(
    `${target.catalog}: +${added} new keys (${Object.keys(catalog.strings).length} total)`,
  );
}

mkdirSync(path.join(ROOT, "build"), { recursive: true });
writeFileSync(
  path.join(ROOT, "build/interpolated-strings-report.txt"),
  [...new Set(interpolatedReport)].join("\n") + "\n",
);
console.log(
  `Interpolated (manual attention): ${new Set(interpolatedReport).size} sites → build/interpolated-strings-report.txt`,
);
