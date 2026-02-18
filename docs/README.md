# CCHS Documentation Project - Technical documentation

This directory contains technical documentation for the CCHS metadata database and MCP server.

## Documentation index

### MCP metadata server

- **[mcp-guide.md](mcp-guide.md)** - Tutorial and how-to guide for querying CCHS variable metadata
- **[mcp-reference.md](mcp-reference.md)** - Complete reference for all 9 MCP tools

### System documentation

- **[architecture.md](architecture.md)** - System architecture, components, and data flow
- **[uid-system.md](uid-system.md)** - UID system specification and examples
- **[glossary.md](glossary.md)** - CCHS terminology and concepts

### Quick links

- **[Main README](../README.md)** - Project overview and quick start
- **[Manifests Documentation](../data/manifests/README.md)** - Collection manifest details

## Quick navigation

**I want to...**

- **Query variable metadata** → [mcp-guide.md](mcp-guide.md)
- **Look up a specific MCP tool** → [mcp-reference.md](mcp-reference.md)
- **Understand the system** → [architecture.md](architecture.md)
- **Create custom UIDs** → [uid-system.md](uid-system.md)
- **Learn CCHS terminology** → [glossary.md](glossary.md)

## Documentation structure

```
docs/
  ├── README.md                  # This file (documentation index)
  ├── mcp-guide.md               # MCP server tutorial and how-to recipes
  ├── mcp-reference.md           # MCP tool reference (all 9 tools)
  ├── architecture.md            # System design and components
  ├── uid-system.md             # UID specification
  └── glossary.md               # CCHS terminology
```

## For developers

If you're contributing to this project:

1. Read [architecture.md](architecture.md) to understand the system design
2. Review [mcp-guide.md](mcp-guide.md) for the metadata query workflow
3. Familiarise yourself with [uid-system.md](uid-system.md) for identifier conventions

## Contributing to documentation

Found an issue or want to improve the documentation?

- Open an issue using the [Documentation template](../.github/ISSUE_TEMPLATE/documentation.md)
- Submit a pull request with your improvements

---

**Last updated**: 2026-02-18
