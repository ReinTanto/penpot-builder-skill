---
name: penpot-builder
description: Use when building, editing, inspecting, or exporting Penpot designs via the Penpot MCP server (tools.penpot). Bakes in the Penpot Plugin API conventions, gotchas, and reusable builder helpers so the agent does not relearn the API each session. For creating screens, components, tokens, design-to-code, and visual verification.
---

# Penpot Builder

Build and edit Penpot designs through the **Penpot MCP server** (`tools.penpot`). This skill exists so the agent does NOT re-derive the Plugin API every session. The MCP tool is the transport; this skill is the knowledge.

## Tools available (via `tools.penpot`)

- `execute_code({ code })` — run JS in the Penpot plugin context. The workhorse for read AND write.
- `high_level_overview()` — the API guide. **Do NOT call it every session** — this skill already encodes it. Only call if you hit an unknown and need the full type list.
- `penpot_api_info({ type, member? })` — docs for a specific type (e.g. `"Text"`, `"Board"`, `"Fill"`). Call only for a type not covered here.
- `export_shape({ shapeId, format?, mode? })` — export a shape/page to PNG/SVG for visual verification. `format` = `"png"`|`"svg"`, `mode` = `"shape"`|`"fill"`.

## Precondition

The user must have a Penpot file open with the **MCP plugin connected** (File → MCP Server → Connect). If `execute_code` throws "no current file" / null file, ask the user to connect the plugin.

## Entry points (use these, NOT the wrong names)

- `penpot.currentFile` — the `File` (has `.name`, `.pages[]`)
- `penpot.currentPage` — the active `Page` (has `.root` = the page's root shape, usually a board)
- `penpot.root`, `penpot.selection`, `penpot.viewport`
- ❌ There is **no** `penpot.file` or `penpot.pages`. Use `penpot.currentFile.pages`.
- ⚠️ **`appendChild` lives on SHAPE objects (boards, groups), NOT on the `Page`.** To add a top-level screen, append to `penpot.currentPage.root` (the page's root board), not to `penpot.currentPage`. A board's children are appended with `board.appendChild(child)`.

## The `storage` object

`storage` persists data and helper functions **across `execute_code` calls** within a session. Define helpers once, reuse them. Guard with `if (!storage.pp) { ... }` so they load exactly once.

## CRITICAL API GOTCHAS (these cause failures)

1. **`width` / `height` are READ-ONLY.** Never do `shape.width = 100`. Use `shape.resize(w, h)`.
2. **`x` / `y` are writable** (top-left of bounding box, page-absolute coords).
3. **Font weights** must be one of: `200, 300, 400, 600, 700, 900`. **`500` is INVALID** → use `600`.
4. **Colors are UPPERCASE hex only** (e.g. `"#4F46E5"`). Lowercase fails.
5. **`fills` / `strokes` / `shadows` arrays are read-only per-element.** To change, **replace the whole array**: `shape.fills = [{ fillColor: "#FF0000", fillOpacity: 1 }]`. No fill = `shape.fills = []`.
6. **`bounds`, `parentX`, `parentY`, `boardX`, `boardY` are read-only** computed props. To position relative to parent: `shape.x = parent.x + parentX`.
7. **Z-order** is determined by child index. Use `shape.bringToFront()`, `sendToBack()`, `bringForward()`, `sendBackward()`.
8. **`penpot.createText(text)`** returns the Text shape; set props then `parent.appendChild(it)`.
9. **Never log what you also return** — duplicate info. Just `return` the data.

## Shape creation (factory methods on `penpot`)

- `penpot.createBoard()` → Board (a screen/frame; set `clipContent = true` to clip overflow)
- `penpot.createRectangle()`, `penpot.createEllipse()`, `penpot.createPath()`, `penpot.createText(str)`, `penpot.createBoolean(type, shapes)`, `penpot.createShapeFromSvg(svg)`
- All: set `x`, `y`, `fills`, `borderRadius`, then `resize(w,h)`, then `parent.appendChild(shape)`.

## Reusable builder helpers (define once via `storage`)

```js
if (!storage.pp) {
  storage.pp = {
    text(parent, str, x, y, w, h, o = {}) {
      const t = penpot.createText(str);
      t.name = o.name || str;
      t.x = x; t.y = y;
      t.fills = [{ fillColor: o.color || "#111111", fillOpacity: 1 }];
      if (o.fontSize) t.fontSize = o.fontSize;
      if (o.fontWeight) t.fontWeight = o.fontWeight;   // 200/300/400/600/700/900
      if (o.align) t.align = o.align;                 // "left"|"center"|"right"
      if (o.letterSpacing) t.letterSpacing = o.letterSpacing;
      t.resize(w, h);
      parent.appendChild(t);
      return t;
    },
    rect(parent, x, y, w, h, fill, radius, name) {
      const r = penpot.createRectangle();
      r.name = name || "rect";
      r.x = x; r.y = y;
      r.fills = [{ fillColor: fill, fillOpacity: 1 }];
      r.borderRadius = radius;
      r.resize(w, h);
      parent.appendChild(r);
      return r;
    },
    board(parent, name, x, y, w, h, fill) {
      const b = penpot.createBoard();
      b.name = name; b.x = x; b.y = y;
      b.resize(w, h);
      b.fills = [{ fillColor: fill || "#FFFFFF", fillOpacity: 1 }];
      b.clipContent = true;
      parent.appendChild(b);
      return b;
    },
    // Button = a GROUP container. The group holds a rect (background) + a text (label).
    // In Penpot only boards/groups are containers — a rect CANNOT contain a text.
    // So: create the bg rect + label text as siblings, then penpot.group([...]) them.
    // The GROUP is the container that gets the interaction; the label is a non-interactive child.
    // Returns { container (the group), background (rect), label (text) }.
    button(parent, name, x, y, w, h, label, opts = {}) {
      const bg = this.rect(parent, x, y, w, h, opts.fill || "#4F46E5", opts.radius ?? 12, name + "-bg");
      const t = this.text(parent, label, x, y, w, h, {
        fontSize: opts.fontSize || 14,
        fontWeight: opts.fontWeight || 600,
        color: opts.color || "#FFFFFF",
        align: "center",
        name: name + "-label",
      });
      const g = penpot.group([bg, t]); // group them -> g.children = [bg, t]
      g.name = name;
      return { container: g, background: bg, label: t };
    },
    // idempotent: clear a board by name before rebuilding
    clear(page, name) {
      page.root.children.filter(c => c.name === name).forEach(c => { try { c.remove(); } catch(e){} });
    },
    // recursive find by name (handles nested shapes)
    findShape(board, name) {
      let found = null;
      const walk = s => { if (s.name === name) { found = s; return; } (s.children || []).forEach(walk); };
      (board.children || []).forEach(walk);
      return found;
    },
    // wire with dedup; returns { shape, ok, actionType }
    wire(board, shapeName, trigger, action) {
      const s = this.findShape(board, shapeName);
      if (!s) return { shape: shapeName, ok: false };
      s.interactions.filter(i => i.trigger === trigger).forEach(i => s.removeInteraction(i));
      s.addInteraction(trigger, action);
      return { shape: shapeName, ok: true, actionType: action.type };
    },
    // action shorthands
    nav(dest) { return { type: "navigate-to", destination: dest }; },
    back() { return { type: "previous-screen" }; },
  };
}
```

## Workflow (follow this order)

1. **Inspect first** (read-only): confirm `penpot.currentFile`, list `pages`, and the target page's `root.children` (names/types/bounds). Never write blindly.
2. **Build** in one `execute_code` call: define helpers (or reuse `storage.pp`), create the board, add children. **Top-level screens are appended to `penpot.currentPage.root`** (the page's root board) — never to `penpot.currentPage` directly. Nested shapes are appended to their container board via `board.appendChild(child)`.
3. **Wire interactions** (if prototyping): use `storage.pp.wire(...)` with dedup. Build all destination screens first, then wire. Verify by reading back `shape.interactions`.
4. **Verify** with `export_shape` (PNG) so you can see the result before declaring done.
5. **Report** what was created (board name, size, child count) and what was wired (element → destination).

## Inspecting structure (read-only snippet)

```js
const page = penpot.currentPage;
return {
  file: penpot.currentFile?.name,
  pages: penpot.currentFile?.pages?.map(p => p.name),
  top: page.root.children.map(c => ({
    name: c.name, type: c.type,
    x: Math.round(c.x), y: Math.round(c.y),
    w: Math.round(c.width), h: Math.round(c.height),
    kids: c.children?.length || 0,
  })),
};
```

## Prototyping / wiring interactions (buttons, navigation)

Every shape has `interactions: Interaction[]` and `addInteraction(trigger, action, delay?)`. This is how you "wire up buttons" — there is no separate tool.

**Triggers:** `"click" | "mouse-enter" | "mouse-leave" | "after-delay"` (after-delay uses the `delay` ms param)

**Actions (objects with a `type` field):**
- `{ type: "navigate-to", destination: Board, animation? }` — go to another board (screen). **This is the button→screen case.** `destination` is any `Board` (top-level screen or nested board).
- `{ type: "open-overlay", destination: Board, position?, closeWhenClickOutside?, addBackgroundOverlay?, animation? }` — open a board as a modal. `position`: `"center"|"top-left"|"top-right"|"top-center"|"bottom-left"|"bottom-right"|"bottom-center"|"manual"`.
- `{ type: "toggle-overlay", destination: Board, ... }` / `{ type: "close-overlay" }`
- `{ type: "previous-screen" }` — back navigation
- `{ type: "open-url", url: string }` — open a link

### Wiring patterns & gotchas

- **`NavigateTo` needs a destination Board** — build the target screens first, then wire. The `destination` must be an actual `Board` object (a top-level screen), not an id or name.
- **`previous-screen`** = native back navigation (returns to the previously visited screen). Use it for "← Back" / "← Kembali" buttons. No destination needed.
- **Dedup before adding.** Re-running a wire script duplicates interactions. Always remove existing interactions with the same trigger first:
  ```js
  shape.interactions.filter(i => i.trigger === trigger).forEach(i => shape.removeInteraction(i));
  shape.addInteraction(trigger, action);
  ```
- **Shapes are often nested.** A button may be a child of a group/board, not a direct child of the screen. Use a recursive `findShape`, not `board.children.find(...)`.
- **Wire the container, not the label.** If a button is a `rect` (e.g. `btn-cash`) with a `text` child (`Cash`), wire the **rect** — the text is just a label and isn't reliably clickable.
- **When CREATING a button, always build it as a group container + inner label, and put the interaction on the container.** A `rect` CANNOT contain a text in Penpot (only boards/groups are containers), so a button is a **group** holding a rect (background) + text (label). Use `storage.pp.button(...)` which returns `{ container, background, label }` — the `container` (group) is the interactive element, the `label` (text) is a centered, non-interactive child. Never put the interaction on a bare text shape.
- **Verify by reading back.** After wiring, read `shape.interactions` to confirm `{ trigger, action.type }` registered. Don't trust success blindly.

### Worked example: wire a multi-screen flow

```js
const page = penpot.currentPage;
const root = page.root;
const byName = n => root.children.find(b => b.name === n);
const login = byName("00 - Login");
const orders = byName("01 - Order List");
const product = byName("02 - Product");

const results = [];
// Login -> Orders
results.push(storage.pp.wire(login, "btn-signin", "click", storage.pp.nav(orders)));
// Orders -> Product (each row)
["store-1","store-2"].forEach(n => results.push(storage.pp.wire(orders, n, "click", storage.pp.nav(product))));
// Product back
results.push(storage.pp.wire(product, "←  Kembali", "click", storage.pp.back()));

// Verify
const ok = results.filter(r => r.ok).length;
return { total: results.length, ok, failures: results.filter(r => !r.ok) };
```

### Creating a button (container + inner label, interaction on container)

Always create buttons this way — the **container** (group) holds the interaction, the **label** (text) is a centered child inside it:

```js
// 1) build the button (group container: bg rect + label text, grouped)
const { container: btn, background, label } = storage.pp.button(
  screen, "btn-submit", 24, 600, 342, 56, "Submit",
  { fill: "#4F46E5", radius: 12, fontSize: 15, fontWeight: 700, color: "#FFFFFF" }
);
// 2) wire the CONTAINER (the group), not the label or the background
storage.pp.wire(screen, "btn-submit", "click", storage.pp.nav(nextScreen));
```

Rules:
- A button is a **group** whose children are a rect (`<name>-bg`, the background) and a text (`<name>-label`, the centered label). Build them as siblings, then `penpot.group([bg, label])`. A rect alone cannot hold the text.
- The **interaction is added to the group container** (`btn-submit`), never to the label or the background.
- Name the group `btn-*` so `findShape` and design-to-code pick it up as the tappable element.
- The label is a **child of the group**, centered over the background (same x/y/w/h as the bg). It is never wired.

### Verify snippet (read back)

```js
function report(boardName, shapeNames) {
  const b = penpot.currentPage.root.children.find(x => x.name === boardName);
  return shapeNames.map(n => {
    const s = storage.pp.findShape(b, n);
    return s ? { shape: n, count: s.interactions.length,
                triggers: s.interactions.map(i => i.trigger),
                actions: s.interactions.map(i => i.action.type) } : { shape: n, count: 0 };
  });
}
```

## Design-to-code

- `penpot.generateMarkup(shapes, { type: "html" })` → HTML string
- `penpot.generateStyle(shapes, { type: "css" })` → CSS string
- Pass an array of shapes (e.g. a board and its children) to get the markup/style.

## Design conventions (for building screens)

- Mobile screens: 390×844 (iPhone) or 360×800 (Android).
- Use a neutral bg (`#F5F6F8`), white cards, one accent color, 12–24px corner radii.
- Keep a consistent type scale: 11 (labels) / 12–13 (meta) / 14–15 (body) / 17–24 (headings).
- Name shapes semantically (`"stat-card-1"`, `"btn-arrive"`) so design-to-code and audits are clean.

## When to call the real tools

- Unknown type/property → `penpot_api_info({ type })`.
- Need the full type list or something changed → `high_level_overview()` (sparingly).
- Visual check → `export_shape`.
