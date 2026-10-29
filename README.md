# penpot-builder

An [OpenCode](https://opencode.ai) **skill** that lets an AI agent build, edit, inspect, prototype, and export [Penpot](https://penpot.app) designs through the **Penpot MCP server** — without relearning the Penpot Plugin API every session.

The skill bakes in the API conventions, the gotchas that actually cause failures, and a set of reusable builder helpers (screens, buttons, navigation wiring, design-to-code). The MCP server is the transport; this skill is the persistent knowledge.

## What it does

- **Builds screens** — boards, rectangles, text, groups, with correct `resize()` / font-weight / color handling
- **Creates buttons correctly** — a group container (background rect + centered label) that carries the interaction, never a bare text
- **Wires interactions** — `navigate-to`, `previous-screen`, `open-overlay`, `open-url` with dedup and read-back verification
- **Inspects structure** — read-only page/shape tree before any write
- **Exports for verification** — PNG/SVG so the agent can see what it built
- **Design-to-code** — `generateMarkup` / `generateStyle` (HTML/CSS)

## Requirements

- [OpenCode](https://opencode.ai) (or any agent that loads skills)
- The **Penpot MCP server** registered in your agent config, pointing at your Penpot instance
- A Penpot file open with the **MCP plugin connected** (File → MCP Server → Connect)

## Install

### Option 1 — Copy into your skills directory

```bash
# OpenCode user skills
cp -r penpot-builder ~/.config/opencode/skills/

# or a project-local skill
cp -r penpot-builder .opencode/skills/
```

### Option 2 — One-liner

```bash
git clone https://github.com/ReinTanto/penpot-builder-skill ~/.config/opencode/skills/penpot-builder
```

### Option 3 — Via the install script

```bash
./install.sh
```

## Register the Penpot MCP server

Add to your OpenCode config (`~/.config/opencode/opencode.jsonc`):

```jsonc
"mcp": {
  "servers": {
    "penpot": {
      "type": "remote",
      "url": "https://<your-penpot-domain>/mcp/stream?userToken=<YOUR_MCP_KEY>"
    }
  }
}
```

Get your MCP key from **Penpot → Your account → Integrations → MCP Server**.

## Usage

Once installed, the agent loads the skill automatically when a task matches (building/editing/prototyping Penpot designs). You just prompt:

- "Build a login screen in my Penpot file"
- "Wire the Sign In button to the dashboard screen"
- "Create a button labeled 'Submit' that navigates to the next screen"
- "Export this screen to PNG so I can see it"

The skill provides a `storage.pp` helper object (`text`, `rect`, `board`, `button`, `wire`, `findShape`, `nav`, `back`, `clear`) that persists across tool calls, so the agent builds reliably the first time.

## Files

- `SKILL.md` — the skill (the actual knowledge the agent loads)
- `install.sh` — copies the skill into your OpenCode skills directory
- `README.md` — this file

## License

[MIT](./LICENSE)
