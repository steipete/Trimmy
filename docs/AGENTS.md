---
summary: "Contributor documentation conventions; repository rules live in the root AGENTS.md."
read_when:
  - Editing contributor documentation or the project website
---

# Documentation conventions

Follow [the repository guidelines](../AGENTS.md) for code style, validation, packaging, and release authorization.

Keep contributor pages aligned with the source and supported SwiftPM workflow. Give Markdown pages a concise `summary` and `read_when` front matter so `pnpm docs:list` can surface them. The website is static HTML/CSS in this directory; regenerate `llms.txt` with `node Scripts/generate-llms.mjs` when its page metadata changes.

Describe current settings tabs and menu labels. Keep `CHANGELOG.md` Trimmy-only and preserve the tab-selection animation when changing settings UI. Use the release checklist only when a release is explicitly requested.
