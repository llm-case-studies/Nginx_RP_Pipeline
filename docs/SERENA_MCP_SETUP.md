# Serena MCP Server Setup Guide

This document explains how to install and configure the Serena MCP server with Claude Code for enhanced coding capabilities.

## What is Serena MCP?

Serena is a powerful, free, open-source coding agent toolkit that provides:
- **Semantic code analysis** and navigation
- **Symbol-level editing** capabilities  
- **Multi-language support** (Python, TypeScript/JavaScript, PHP, Go, Rust, C/C++, Java)
- **IDE-like features** through Model Context Protocol (MCP)
- **Web-based dashboard** for monitoring and logs

## Prerequisites

Ensure `uv` (Python package manager) is installed:

```bash
# Check if uv is installed
uv --version

# Install uv if needed
curl -LsSf https://astral.sh/uv/install.sh | sh
# OR on macOS: brew install uv  
# OR on Windows: powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

## Installation Methods

### Method 1: Local Project Configuration (Recommended)

Install Serena for the current project:

```bash
cd /path/to/your/project
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena-mcp-server --context ide-assistant --project $(pwd)
```

This creates a local configuration that's specific to your project.

### Method 2: Project-Level Shared Configuration

Create a `.mcp.json` file in your project root to share MCP configuration with team members:

```json
{
  "servers": {
    "serena": {
      "command": "uvx",
      "args": [
        "--from",
        "git+https://github.com/oraios/serena",
        "serena-mcp-server",
        "--context",
        "ide-assistant",
        "--project",
        "$(pwd)"
      ],
      "description": "Serena MCP Server - Coding agent toolkit"
    }
  }
}
```

### Method 3: Global User Configuration

For access across all projects, add Serena to your global user configuration:

```bash
claude mcp add --scope user serena -- uvx --from git+https://github.com/oraios/serena serena-mcp-server --context ide-assistant
```

## Verification

Check if Serena is properly installed and connected:

```bash
# List all MCP servers
claude mcp list

# Get detailed info about Serena
claude mcp get serena
```

Expected output:
```
serena: uvx --from git+https://github.com/oraios/serena serena-mcp-server ... - ✓ Connected
```

## Key Features Available Through Claude Code

Once installed, Serena provides these enhanced capabilities:

1. **Semantic Code Search**: Find functions, classes, and symbols across your codebase
2. **Intelligent Code Editing**: Make precise, context-aware code modifications
3. **Multi-file Analysis**: Understand relationships between different code files
4. **Symbol Navigation**: Jump to definitions, find usages, and explore code structure
5. **Language-Specific Analysis**: Tailored support for different programming languages

## Usage Tips

1. **Project Activation**: Ask Claude to "activate the current project" or specify the project path
2. **Initial Instructions**: If Claude doesn't automatically read Serena's instructions, run:
   ```
   /mcp__serena__initial_instructions
   ```
3. **Dashboard Access**: Serena runs a web dashboard on localhost for monitoring logs
4. **No API Keys Required**: Works with Claude's free tier (paid models can use API keys in `.env`)

## Troubleshooting

### Server Not Connected
- Ensure `uv` is installed and accessible
- Check network connectivity for git clone operations
- Restart Claude Code after configuration changes

### Missing Tools
- Verify Serena is listed in `claude mcp list`
- Ask Claude to read initial instructions explicitly
- Check for any error messages in the dashboard

### Performance Issues
- Large codebases may take time for initial analysis
- Use specific file/directory targeting for better performance
- Consider excluding build/node_modules directories

## Configuration for Other AI Sessions

This project includes:
- **Local configuration**: Automatically available when working in this directory
- **Project `.mcp.json`**: Shareable with team members and other AI sessions
- **Documentation**: This guide for setting up Serena on new machines/sessions

To replicate this setup on another machine:
1. Clone the project repository
2. Install `uv` if not available
3. Run: `claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena-mcp-server --context ide-assistant --project $(pwd)`
4. Verify with: `claude mcp list`

## Benefits for Development Workflow

- **Faster Code Navigation**: Semantic search instead of text-based grep
- **Intelligent Refactoring**: Context-aware code modifications
- **Multi-language Support**: Consistent experience across different technologies
- **Enhanced Code Understanding**: Better analysis of code relationships and dependencies
- **Free and Open Source**: No licensing costs or vendor lock-in

---

**Status**: ✅ **CONFIGURED** - Serena MCP server is installed and ready for use.

**Next Steps**: Start using Serena's enhanced coding capabilities in your Claude Code sessions!