// くりーんぶんしょ — 文字処理ルールの参照実装（JavaScript）
//
// Swift 版（Sources/CleanBunshoCore）と同じ結果を返すことを目的とした実装。
// ブラウザ版・Windows 版へ移植するときの基準として使い、
// Tests/CleanBunshoCoreTests/Fixtures/cases.json を両方で通す。
//
//   node tools/check-fixtures.mjs   … このファイルで cases.json を検証

export const RULES = [
  // id, 既定, 種類（scalar = 1文字ずつ / text = 文章全体）
  ["zeroWidth", true, "scalar"],
  ["bidi", true, "scalar"],
  ["tag", true, "scalar"],
  ["control", true, "scalar"],
  ["specialSpace", true, "scalar"],
  ["ideographicSpace", false, "scalar"],
  ["lineSeparator", true, "scalar"],
  ["newline", true, "scalar"],
  ["trailingWhitespace", true, "text"],
  ["trim", true, "text"],
  ["collapseBlankLines", false, "text"],
  ["curlyQuotes", false, "scalar"],
  ["dashes", false, "scalar"],
];

export function defaultOptions(overrides = {}) {
  const o = {};
  for (const [id, on] of RULES) o[id] = on;
  return { ...o, ...overrides };
}

const ZERO_WIDTH = new Set([
  0x200b, 0x200c, 0x200d, 0x2060, 0xfeff, 0x00ad, 0x034f, 0x180e,
  0x2061, 0x2062, 0x2063, 0x2064, 0x115f, 0x1160, 0x3164, 0xffa0,
]);
const LINE_SEPARATORS = new Set([0x2028, 0x2029, 0x0085]);
const QUOTES = new Map([[0x201c, '"'], [0x201d, '"'], [0x2018, "'"], [0x2019, "'"]]);
const DASHES = new Map([[0x2014, "-"], [0x2013, "-"]]);

/** 1文字ずつ判定するルールの分類。対象外は null */
export function classify(cp) {
  if (ZERO_WIDTH.has(cp)) return "zeroWidth";
  if (cp === 0x200e || cp === 0x200f || cp === 0x061c) return "bidi";
  if ((cp >= 0x202a && cp <= 0x202e) || (cp >= 0x2066 && cp <= 0x2069)) return "bidi";
  if (cp >= 0xe0000 && cp <= 0xe007f) return "tag";
  if (LINE_SEPARATORS.has(cp)) return "lineSeparator";
  if (cp === 0x0d) return "newline";
  if ((cp <= 0x1f && cp !== 0x09 && cp !== 0x0a) || (cp >= 0x7f && cp <= 0x9f)) return "control";
  if (cp === 0x00a0 || cp === 0x202f || cp === 0x205f || (cp >= 0x2000 && cp <= 0x200a)) return "specialSpace";
  if (cp === 0x3000) return "ideographicSpace";
  if (QUOTES.has(cp)) return "curlyQuotes";
  if (DASHES.has(cp)) return "dashes";
  return null;
}

const EMOJI = /\p{Emoji}/u;
const MODIFIER = /\p{Emoji_Modifier}/u;
/** 絵文字かどうか（Swift 側と同じ判定: Emoji かつ U+00FF より後、または肌色修飾子） */
function isEmojiScalar(cp) {
  if (cp === undefined) return false;
  const ch = String.fromCodePoint(cp);
  return (EMOJI.test(ch) && cp > 0xff) || MODIFIER.test(ch);
}

/**
 * 保護する（消さない）位置を返す
 * - 絵文字の間にある ZWJ（直前が VS16 の場合はその前を見る）
 * - 🏴 に続くタグ文字（旗の絵文字）
 */
export function protectedIndices(cps) {
  const set = new Set();
  let inFlag = false;
  for (let i = 0; i < cps.length; i++) {
    const cp = cps[i];
    if (cp === 0x200d) {
      const prev = cps[i - 1] === 0xfe0f ? cps[i - 2] : cps[i - 1];
      if (isEmojiScalar(prev) && isEmojiScalar(cps[i + 1])) set.add(i);
    }
    if (cp >= 0xe0020 && cp <= 0xe007f && (inFlag || cps[i - 1] === 0x1f3f4)) {
      set.add(i);
      inFlag = cp !== 0xe007f;
    } else {
      inFlag = false;
    }
  }
  return set;
}

function stripTrailingSpaces(line) {
  let end = line.length;
  while (end > 0 && (line[end - 1] === " " || line[end - 1] === "\t")) end--;
  return line.slice(0, end);
}

export function clean(text, options = defaultOptions()) {
  const cps = Array.from(text, (c) => c.codePointAt(0));
  const prot = protectedIndices(cps);
  let out = "";
  let removed = 0;
  let replaced = 0;
  const breakdown = {};
  const bump = (rule) => (breakdown[rule] = (breakdown[rule] ?? 0) + 1);

  for (let i = 0; i < cps.length; i++) {
    const cp = cps[i];
    const rule = classify(cp);
    if (!rule || prot.has(i) || !options[rule]) {
      out += String.fromCodePoint(cp);
      continue;
    }
    switch (rule) {
      case "newline":
        // CRLF → LF（CR を落とす）/ 単独の CR → LF。数には入れない
        if (cps[i + 1] !== 0x0a) out += "\n";
        break;
      case "lineSeparator":
        out += "\n"; replaced++; bump(rule);
        break;
      case "specialSpace":
      case "ideographicSpace":
        out += " "; replaced++; bump(rule);
        break;
      case "curlyQuotes":
        out += QUOTES.get(cp); replaced++; bump(rule);
        break;
      case "dashes":
        out += DASHES.get(cp); replaced++; bump(rule);
        break;
      default:
        removed++; bump(rule);
    }
  }

  if (options.trailingWhitespace) {
    out = out
      .split("\n")
      .map((line) => (line.endsWith("\r") ? stripTrailingSpaces(line.slice(0, -1)) + "\r" : stripTrailingSpaces(line)))
      .join("\n");
  }
  if (options.collapseBlankLines) {
    // 3行以上の空行（改行4つ以上）→ 空行1行（改行2つ）
    out = out.replace(/\n{4,}/g, "\n\n");
  }
  if (options.trim) {
    out = out.replace(/^[ \t\r\n]+/, "").replace(/[ \t\r\n]+$/, "");
  }

  return { text: out, removed, replaced, breakdown, changed: out !== text };
}
