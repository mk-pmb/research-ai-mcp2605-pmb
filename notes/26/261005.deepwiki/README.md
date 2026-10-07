
Testing MCP with DeepWiki
-------------------------

### Existing docs

The [GWDG MCP docs][gwdg-dpcs-mcp] example uses the
[DeepWiki MCP server](https://mcp.deepwiki.com/mcp).
Their example asks about the [Chat AI repo](https://github.com/gwdg/chat-ai),
which by now (2026-10-05) is indexed in the DeepWiki.

  [gwdg-dpcs-mcp]: https://docs.hpc.gwdg.de/services/ai-services/chat-ai/features/mcp/index.html

Even with MCP disabled, some models' hallucinations are quite convincing,
so a positive lookup may not be too useful for testing MCP connectivity.


### A more reliable strategy

… is to ask for a non-existent repo that would be easy to hallucinate about,
and explicitly request an MCP lookup.
If you get an error report, the AI has probably consulted DeepWiki.

* For models that tend to read "MCP" as "Minecraft Protocol",
  you may have to mention the full name.


### Example prompt

For easy comparison, I first ask with MCP disabled:

```text
I tried to enable the DeepWiki MCP (Model Context Protocol) server
for this conversation. Does it work? Can you use that to look up the
https://github.com/gwdg/chat-ai-aspell-connector project description?
```

Then I enable MCP and ask:

```text
Retry please.
```


### Test results

* [Qwen](qwen/)












