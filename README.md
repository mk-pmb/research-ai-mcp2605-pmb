
<!--#echo json="package.json" key="name" underline="=" -->
research-ai-mcp2605-pmb
=======================
<!--/#echo -->

<!--#echo json="package.json" key="description" -->
Experimental MCP (Model Context Protocol) toolbox for sharing my local git
repos and notes with an AI.
<!--/#echo -->



Research notes
--------------

* The [☁️ Academic Cloud](https://www.academiccloud.de/) &rarr;
  [💬 Chat AI](https://chat-ai.academiccloud.de/) &rarr;
  🛠️ config panel has a setting for an MCP (Model Context Protocol) URL,
  to allow connecting it to your own MCP server.
* MCP servers come in two interface types: __stdio__ and __HTTPS__.
* GitHub runs a public MCP server, but it has far more capabilities than
  I’d be comfortable granting, and parts of the conversation could end up
  being sent to GitHub, so it’s better to set up your own MCP server.
* The official [reference implementations][mcp-ref-servers]
  include MCP stdio servers for…
  * `filesystem` and `git`,
    making it very easy to serve already-published files.
  * `fetch` and `memory` could also be useful,
    but they would need access restrictions to avoid leaking conversation data.
* Project [mcp-proxy](https://github.com/sparfenyuk/mcp-proxy)
  can act as a HTTPS-MCP client, making the servers' features available
  via stdio, and, more relevant for here, the reverse.
  * To let `mcp-proxy` work smoothly with `mcp/filesystem` and `mcp/git`,
    those components need to be installed in the same Docker container.



Known issues
------------

* Needs more/better tests and docs.





<!--#toc stop="scan" -->


  [mcp-ref-servers]: https://github.com/modelcontextprotocol/servers/#-reference-servers


&nbsp;


License
-------
<!--#echo json="package.json" key="license" -->
ISC
<!--/#echo -->
