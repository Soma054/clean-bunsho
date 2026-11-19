// cases.json を参照実装（reference-cleaner.mjs）で検証する
//   node tools/check-fixtures.mjs
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { clean, defaultOptions } from "./reference-cleaner.mjs";

const path = fileURLToPath(new URL("../Tests/CleanBunshoCoreTests/Fixtures/cases.json", import.meta.url));
const { cases } = JSON.parse(readFileSync(path, "utf8"));
const show = (s) => JSON.stringify(s).replace(/[^\x20-\x7e぀-ヿ一-鿿]/gu, (c) => "\\u{" + c.codePointAt(0).toString(16) + "}");

let failed = 0;
for (const c of cases) {
  const r = clean(c.input, defaultOptions(c.options));
  const errs = [];
  if (r.text !== c.expected) errs.push(`text: ${show(r.text)} != ${show(c.expected)}`);
  if (r.removed !== c.removed) errs.push(`removed: ${r.removed} != ${c.removed}`);
  if (r.replaced !== c.replaced) errs.push(`replaced: ${r.replaced} != ${c.replaced}`);
  if (r.changed !== (c.input !== c.expected)) errs.push("changed flag");
  if (errs.length) {
    failed++;
    console.log(`NG ${c.name}\n   ${errs.join("\n   ")}`);
  } else {
    console.log(`ok ${c.name}`);
  }
}
console.log(`\n${cases.length - failed}/${cases.length} passed`);
process.exit(failed ? 1 : 0);
