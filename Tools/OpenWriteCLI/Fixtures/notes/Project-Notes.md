# Project Notes

## Ingestion pipeline

The ingestion pipeline chunks notes by heading, embeds them with LM Studio or a local hash fallback, and stores vectors in `index.json`.

Hybrid search combines cosine similarity with boosted title and filename matches.

## Graph tour

OpenWrite can visualize note links: nodes are pages, edges are wikilinks. Use the graph tab to explore connectivity.
