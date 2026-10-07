
⚠ Token Count Coincidence ⚠
---------------------------

In `01.rsp.sse.txt`, 1 initial empty content fragment + first reply word +
144 additions = 146 fragments, which __coincides__ with `completion_tokens`
in the final stats report. However, GPT OSS warns decisively that the
server's choice of stream splitting is a stream implementation detail
__may be independent__ from tokenization and also __may differ by model__.


