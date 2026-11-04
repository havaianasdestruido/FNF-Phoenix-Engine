/**
 * A small, dependency-free Haxe source parser.
 *
 * It is deliberately *lexical* rather than semantic: Phoenix Engine's `source/`
 * tree is plain Haxe 4 with heavy `#if` usage, and all the documentation
 * generator needs is the shape of each module (types, fields, signatures, doc
 * comments and the conditional-compilation flags guarding them).
 *
 * Exported entry point: `parseHaxeFile(sourceText, relativePath)`.
 */

const TYPE_KEYWORDS = ['class', 'interface', 'enum', 'abstract', 'typedef'];

/** Strip a `/** ... *\/` block into readable markdown-ish text. */
function cleanDocComment(raw) {
  if (!raw) return '';
  return raw
    .replace(/^\s*\/\*\*?/, '')
    .replace(/\*\/\s*$/, '')
    .split('\n')
    .map((line) => line.replace(/^\s*\*ically?/, '').replace(/^\s*\* ?/, '').trimEnd())
    .join('\n')
    .trim();
}

/** Strip `//` line comments into readable text. */
function cleanLineComments(lines) {
  return lines
    .map((line) => line.replace(/^\s*\/\/ ?/, '').trimEnd())
    .join('\n')
    .trim();
}

/**
 * Walk the file once, remembering:
 *  - the active `#if` / `#elseif` / `#else` stack for every line
 *  - the doc comment (if any) immediately preceding every line
 */
function indexFile(text) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  const conditions = [];   // per-line array of active conditional flags
  const docs = [];         // per-line doc comment attached to that line

  const stack = [];
  let pendingDoc = null;
  let pendingLineComment = [];
  let inBlockComment = false;
  let blockBuffer = [];
  let blockIsDoc = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    if (inBlockComment) {
      blockBuffer.push(line);
      if (trimmed.includes('*/')) {
        inBlockComment = false;
        if (blockIsDoc) pendingDoc = cleanDocComment(blockBuffer.join('\n'));
        blockBuffer = [];
      }
      conditions.push(stack.slice());
      docs.push(null);
      continue;
    }

    if (trimmed.startsWith('/*')) {
      blockIsDoc = trimmed.startsWith('/**');
      blockBuffer = [line];
      if (!trimmed.includes('*/', 2)) {
        inBlockComment = true;
      } else {
        if (blockIsDoc) pendingDoc = cleanDocComment(blockBuffer.join('\n'));
        blockBuffer = [];
      }
      conditions.push(stack.slice());
      docs.push(null);
      continue;
    }

    // Conditional compilation bookkeeping.
    const condMatch = trimmed.match(/^#(if|elseif|else|end)\b\s*(.*)$/);
    if (condMatch) {
      const [, kind, rest] = condMatch;
      if (kind === 'if') stack.push(normalizeCondition(rest));
      else if (kind === 'elseif') { stack.pop(); stack.push(normalizeCondition(rest)); }
      else if (kind === 'else') { const prev = stack.pop(); stack.push(prev ? `!(${prev})` : '!'); }
      else stack.pop();
      conditions.push(stack.slice());
      docs.push(null);
      continue;
    }

    if (trimmed.startsWith('//')) {
      pendingLineComment.push(trimmed);
      conditions.push(stack.slice());
      docs.push(null);
      continue;
    }

    conditions.push(stack.slice());

    if (trimmed === '') {
      // Blank lines break a run of `//` comments but keep a `/** */` block alive.
      pendingLineComment = [];
      docs.push(null);
      continue;
    }

    let doc = pendingDoc;
    if (!doc && pendingLineComment.length) doc = cleanLineComments(pendingLineComment);
    docs.push(doc || null);
    pendingDoc = null;
    pendingLineComment = [];
  }

  return { lines, conditions, docs };
}

/** `(cpp && !flash)` -> `cpp && !flash` */
function normalizeCondition(raw) {
  let cond = raw.split('//')[0].trim();
  while (cond.startsWith('(') && cond.endsWith(')')) {
    // only strip when the parentheses actually wrap the whole expression
    let depth = 0;
    let wraps = true;
    for (let i = 0; i < cond.length; i++) {
      if (cond[i] === '(') depth++;
      else if (cond[i] === ')') {
        depth--;
        if (depth === 0 && i !== cond.length - 1) { wraps = false; break; }
      }
    }
    if (!wraps) break;
    cond = cond.slice(1, -1).trim();
  }
  return cond;
}

/** Split `a:Int, b:Array<String>, ?c:Foo<Bar, Baz>` respecting nesting. */
function splitTopLevel(input, separator = ',') {
  const out = [];
  let depth = 0;
  let current = '';
  for (const ch of input) {
    if ('(<[{'.includes(ch)) depth++;
    else if (')>]}'.includes(ch)) depth--;
    if (ch === separator && depth === 0) {
      out.push(current.trim());
      current = '';
    } else current += ch;
  }
  if (current.trim()) out.push(current.trim());
  return out;
}

/** Read a balanced `(...)` starting at `startIdx` inside the joined text. */
function readBalanced(text, startIdx, open = '(', close = ')') {
  let depth = 0;
  for (let i = startIdx; i < text.length; i++) {
    if (text[i] === open) depth++;
    else if (text[i] === close) {
      depth--;
      if (depth === 0) return { body: text.slice(startIdx + 1, i), end: i };
    }
  }
  return { body: text.slice(startIdx + 1), end: text.length };
}

function parseParams(raw) {
  if (!raw.trim()) return [];
  return splitTopLevel(raw).map((part) => {
    const optional = part.startsWith('?');
    const body = optional ? part.slice(1) : part;
    const eq = indexOfTopLevel(body, '=');
    const decl = eq === -1 ? body : body.slice(0, eq);
    const def = eq === -1 ? null : body.slice(eq + 1).trim();
    const colon = indexOfTopLevel(decl, ':');
    const name = (colon === -1 ? decl : decl.slice(0, colon)).trim();
    const type = colon === -1 ? null : decl.slice(colon + 1).trim();
    return { name, type, optional: optional || def !== null, defaultValue: def };
  });
}

/** Remove a trailing `// ...` comment, ignoring `//` inside string literals. */
function stripTrailingComment(text) {
  let quote = null;
  for (let i = 0; i < text.length - 1; i++) {
    const ch = text[i];
    if (quote) {
      if (ch === '\\') i++;
      else if (ch === quote) quote = null;
      continue;
    }
    if (ch === '"' || ch === "'") { quote = ch; continue; }
    if (ch === '/' && text[i + 1] === '/') return text.slice(0, i).trimEnd();
  }
  return text;
}

function indexOfTopLevel(text, char) {
  let depth = 0;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if ('(<[{'.includes(ch)) depth++;
    else if (')>]}'.includes(ch)) depth--;
    else if (ch === char && depth === 0) return i;
  }
  return -1;
}

/**
 * Parse a single Haxe module.
 * @returns {{package: string, path: string, types: Array<object>, imports: string[]}}
 */
export function parseHaxeFile(text, relativePath) {
  const { lines, conditions, docs } = indexFile(text);
  const joined = lines.join('\n');

  const pkgMatch = joined.match(/^\s*package\s+([\w.]*)\s*;/m);
  const pkg = pkgMatch ? pkgMatch[1] : '';

  const imports = [];
  for (const m of joined.matchAll(/^\s*import\s+([\w.*]+)/gm)) imports.push(m[1]);

  const types = [];
  let current = null;
  let braceDepth = 0;
  let typeBraceDepth = null;
  let pendingMeta = [];
  // Brace depth snapshots for `#if` blocks: every branch of a conditional must
  // start from the same depth, otherwise `#if A ... { #else ... { #end` counts
  // one opening brace per branch and the tracker drifts for the rest of the file.
  const condStack = [];

  // character offset of the start of each line, for balanced reads
  const offsets = [];
  let acc = 0;
  for (const line of lines) { offsets.push(acc); acc += line.length + 1; }

  for (let i = 0; i < lines.length; i++) {
    const rawLine = lines[i];
    const line = rawLine.trim();
    if (!line || line.startsWith('//') || line.startsWith('#') || line.startsWith('*')) {
      if (line.startsWith('#')) {
        if (/^#if\b/.test(line)) condStack.push(braceDepth);
        else if (/^#(else|elseif)\b/.test(line) && condStack.length) {
          braceDepth = condStack[condStack.length - 1];
        } else if (/^#end\b/.test(line)) condStack.pop();
      }
      updateDepth();
      continue;
    }

    if (line.startsWith('@')) {
      pendingMeta.push(line);
      updateDepth();
      continue;
    }

    const typeMatch = line.match(
      /^(?:(?:final|public|private|extern|@:\S+)\s+)*(class|interface|enum|abstract|typedef)\s+([A-Za-z_]\w*)\s*(<[^>]*>)?(.*)$/,
    );

    if (typeMatch && (braceDepth === 0 || current === null)) {
      const [, kind, name, generics, rest] = typeMatch;
      const extendsMatch = rest.match(/extends\s+([\w.<>, ]+?)(?=\s+implements|\s*\{|\s*$)/);
      const implementsAll = [...rest.matchAll(/implements\s+([\w.<>, ]+?)(?=\s+implements|\s*\{|\s*$)/g)].map(
        (m) => m[1].trim(),
      );

      current = {
        kind,
        name,
        generics: generics || '',
        extends: extendsMatch ? extendsMatch[1].trim() : null,
        implements: implementsAll,
        doc: docs[i] || '',
        meta: pendingMeta.slice(),
        conditions: conditions[i].slice(),
        line: i + 1,
        fields: [],
        methods: [],
        aliasOf: null,
        structureFields: [],
        enumValues: [],
      };

      if (kind === 'typedef') {
        const eq = rest.indexOf('=');
        if (eq !== -1) {
          const after = rest.slice(eq + 1).trim();
          if (after.startsWith('{')) {
            const startOffset = offsets[i] + rawLine.indexOf('{', rawLine.indexOf('='));
            const { body } = readBalanced(joined, startOffset, '{', '}');
            current.structureFields = parseStructureBody(body);
          } else if (after) {
            current.aliasOf = after.replace(/;$/, '').trim();
          }
        }
      }

      types.push(current);
      pendingMeta = [];
      typeBraceDepth = braceDepth;
      updateDepth();
      continue;
    }

    // Only declarations sitting directly in the type body are members. Anything
    // deeper is a local inside a function body (Phoenix registers most of its
    // script callbacks from inside `register()`, so this matters a lot).
    const inTypeBody = typeBraceDepth !== null && braceDepth === typeBraceDepth + 1;

    if (current && inTypeBody) {
      const field = parseMember(line, rawLine, i);
      if (field) {
        field.doc = docs[i] || '';
        field.meta = pendingMeta.slice();
        field.conditions = conditions[i].slice();
        field.line = i + 1;
        if (field.isMethod) current.methods.push(field);
        else current.fields.push(field);
        pendingMeta = [];
        updateDepth();
        continue;
      }

      if (current.kind === 'enum' && /^[A-Z]\w*\s*(\(.*\))?\s*;/.test(line)) {
        const m = line.match(/^([A-Z]\w*)\s*(\(([^)]*)\))?/);
        current.enumValues.push({
          name: m[1],
          params: m[3] ? parseParams(m[3]) : [],
          doc: docs[i] || '',
        });
      }
    }

    pendingMeta = [];
    updateDepth();

    function updateDepth() {
      for (const ch of rawLine) {
        if (ch === '{') braceDepth++;
        else if (ch === '}') {
          braceDepth--;
          if (current && typeBraceDepth !== null && braceDepth <= typeBraceDepth) {
            current = null;
            typeBraceDepth = null;
          }
        }
      }
    }
  }

  return { package: pkg, path: relativePath, types, imports };

  /** Parse one `var` / `function` declaration line. */
  function parseMember(line, rawLine, lineIdx) {
    const memberMatch = line.match(
      /^((?:(?:public|private|static|inline|dynamic|override|final|extern|overload)\s+)*)(var|function|final)\s+([A-Za-z_]\w*)(<[^>]*>)?\s*(.*)$/,
    );
    if (!memberMatch) return null;

    const [, modifiersRaw, keyword, name, generics, rest] = memberMatch;
    const modifiers = modifiersRaw.trim().split(/\s+/).filter(Boolean);

    const base = {
      name,
      generics: generics || '',
      isPublic: modifiers.includes('public'),
      isStatic: modifiers.includes('static'),
      isInline: modifiers.includes('inline'),
      isOverride: modifiers.includes('override'),
      isFinal: keyword === 'final' || modifiers.includes('final'),
      modifiers,
    };

    if (keyword === 'function') {
      const parenIdx = rawLine.indexOf('(', rawLine.indexOf(name));
      const { body, end } = readBalanced(joined, offsets[lineIdx] + parenIdx);
      const after = joined.slice(end + 1).split('\n')[0];
      const retMatch = after.match(/^\s*:\s*([^={;]+)/);
      return {
        ...base,
        isMethod: true,
        params: parseParams(body),
        returnType: retMatch ? retMatch[1].trim() : null,
      };
    }

    // var / final field
    const decl = stripTrailingComment(rest).replace(/;\s*$/, '');
    const propMatch = decl.match(/^\(\s*([\w]+)\s*,\s*([\w]+)\s*\)(.*)$/);
    let accessors = null;
    let remainder = decl;
    if (propMatch) {
      accessors = { get: propMatch[1], set: propMatch[2] };
      remainder = propMatch[3];
    }
    const eq = indexOfTopLevel(remainder, '=');
    const typePart = eq === -1 ? remainder : remainder.slice(0, eq);
    const defaultValue = eq === -1 ? null : remainder.slice(eq + 1).trim().replace(/;$/, '');
    const colon = indexOfTopLevel(typePart, ':');
    return {
      ...base,
      isMethod: false,
      accessors,
      type: colon === -1 ? null : typePart.slice(colon + 1).trim(),
      defaultValue: defaultValue || null,
    };
  }
}

/** Parse the body of an anonymous-structure typedef. */
function parseStructureBody(body) {
  const out = [];
  const entries = body.split('\n');
  let pendingOptional = false;
  for (const rawEntry of entries) {
    const entry = rawEntry.trim();
    if (!entry || entry.startsWith('//')) continue;
    const optionalMeta = entry.includes('@:optional');
    const cleaned = entry.replace(/@:optional/g, '').trim();
    const m = cleaned.match(/^(?:var|final)?\s*(\??)([A-Za-z_]\w*)\s*:\s*(.+?);?$/);
    if (!m) { pendingOptional = false; continue; }
    out.push({
      name: m[2],
      type: m[3].replace(/;$/, '').trim(),
      optional: optionalMeta || m[1] === '?' || pendingOptional,
    });
    pendingOptional = false;
  }
  return out;
}

/** Render a method signature the way it appears in Haxe source. */
export function formatSignature(member) {
  const params = member.params
    .map((p) => {
      const q = p.optional && !p.defaultValue ? '?' : '';
      const type = p.type ? `:${p.type}` : '';
      const def = p.defaultValue ? ` = ${p.defaultValue}` : '';
      return `${q}${p.name}${type}${def}`;
    })
    .join(', ');
  const ret = member.returnType ? `:${member.returnType}` : '';
  const mods = [];
  if (member.isStatic) mods.push('static');
  if (member.isInline) mods.push('inline');
  if (member.isOverride) mods.push('override');
  const prefix = mods.length ? `${mods.join(' ')} ` : '';
  return `${prefix}function ${member.name}${member.generics}(${params})${ret}`;
}

export { parseParams, splitTopLevel };
