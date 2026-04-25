---
name: sk:rag-vector-db
description: RAG (Retrieval-Augmented Generation) with vector databases - Pinecone, Weaviate, Qdrant. Embedding strategies (OpenAI ada-002, sentence-transformers), hybrid search, retrieve+rerank+generate patterns.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: ai
argument-hint: "[RAG pipeline task or vector DB operation]"
---

# sk:rag-vector-db

Complete guide for building RAG (Retrieval-Augmented Generation) pipelines with production-grade vector databases.

## When to Use

- Building a Q&A system over custom documents/knowledge base
- Implementing semantic search over large text corpora
- Choosing between Pinecone, Weaviate, and Qdrant
- Selecting embedding models for different languages/domains
- Implementing reranking for better retrieval precision
- Scaling RAG pipelines to production

---

## 1. RAG Architecture Overview

```
Documents → Chunking → Embedding → Vector DB (index)
                                        ↓
User Query → Embedding → Vector Search → Top-K Chunks
                                        ↓
                              Reranker (optional)
                                        ↓
                         LLM (Query + Context) → Answer
```

---

## 2. Embedding Strategies

### OpenAI text-embedding-ada-002 (1536 dims)

```typescript
import OpenAI from 'openai';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export async function embedText(text: string): Promise<number[]> {
  const response = await openai.embeddings.create({
    model: 'text-embedding-ada-002',
    input: text.replace(/\n/g, ' '), // normalize newlines
  });
  return response.data[0].embedding;
}

// Batch embedding (more efficient)
export async function embedBatch(texts: string[]): Promise<number[][]> {
  const response = await openai.embeddings.create({
    model: 'text-embedding-ada-002',
    input: texts.map((t) => t.replace(/\n/g, ' ')),
  });
  return response.data.map((d) => d.embedding);
}
```

### OpenAI text-embedding-3-small/large (newer, cheaper)

```typescript
// text-embedding-3-small: 1536 dims, cheaper than ada-002
// text-embedding-3-large: 3072 dims, higher quality
const response = await openai.embeddings.create({
  model: 'text-embedding-3-small',
  input: text,
  dimensions: 512,  // can reduce dims to save storage/cost
});
```

### sentence-transformers (local, free)

```python
# Python — sentence-transformers
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')    # 384 dims, fast
# or: 'all-mpnet-base-v2'                          # 768 dims, better quality
# or: 'paraphrase-multilingual-MiniLM-L12-v2'      # multilingual

embeddings = model.encode(['text 1', 'text 2'], batch_size=32, show_progress_bar=True)
```

### Embedding Model Comparison

| Model | Dims | Quality | Cost | Multilingual |
|---|---|---|---|---|
| text-embedding-ada-002 | 1536 | Good | $0.10/1M tokens | No |
| text-embedding-3-small | 1536 | Better | $0.02/1M tokens | No |
| text-embedding-3-large | 3072 | Best (OpenAI) | $0.13/1M tokens | No |
| all-MiniLM-L6-v2 | 384 | Good | Free (local) | No |
| paraphrase-multilingual-MiniLM | 384 | Good | Free (local) | Yes (50+ langs) |

---

## 3. Document Chunking

```typescript
// utils/text-chunker.ts
interface ChunkOptions {
  chunk_size: number;      // tokens or chars
  chunk_overlap: number;   // overlap between chunks
  separator?: string;
}

export function chunkText(text: string, options: ChunkOptions): string[] {
  const { chunk_size, chunk_overlap, separator = '\n\n' } = options;
  const chunks: string[] = [];
  const paragraphs = text.split(separator);
  let current_chunk = '';

  for (const paragraph of paragraphs) {
    if ((current_chunk + paragraph).length > chunk_size) {
      if (current_chunk) chunks.push(current_chunk.trim());
      // Overlap: keep last N chars from previous chunk
      current_chunk = current_chunk.slice(-chunk_overlap) + paragraph;
    } else {
      current_chunk += (current_chunk ? separator : '') + paragraph;
    }
  }

  if (current_chunk) chunks.push(current_chunk.trim());
  return chunks.filter((c) => c.length > 50); // filter tiny chunks
}

// Usage
const chunks = chunkText(document_text, {
  chunk_size: 1000,    // ~750 tokens
  chunk_overlap: 200,
});
```

---

## 4. Pinecone

```bash
npm install @pinecone-database/pinecone
```

```typescript
import { Pinecone } from '@pinecone-database/pinecone';

const pc = new Pinecone({ apiKey: process.env.PINECONE_API_KEY! });

// Create index (once)
await pc.createIndex({
  name: 'knowledge-base',
  dimension: 1536,           // match embedding model
  metric: 'cosine',
  spec: {
    serverless: { cloud: 'aws', region: 'us-east-1' },
  },
});

const index = pc.index('knowledge-base');

// Upsert vectors
await index.upsert([
  {
    id: 'doc_001_chunk_0',
    values: embedding,
    metadata: {
      text: chunk_text,
      source: 'document.pdf',
      page: 1,
      created_at: new Date().toISOString(),
    },
  },
]);

// Query
const query_result = await index.query({
  vector: query_embedding,
  topK: 10,
  includeMetadata: true,
  filter: { source: { $eq: 'document.pdf' } },  // metadata filter
});

const contexts = query_result.matches
  .filter((m) => m.score! > 0.75)   // threshold
  .map((m) => m.metadata!.text as string);
```

---

## 5. Qdrant

```bash
npm install @qdrant/js-client-rest
# docker run -p 6333:6333 qdrant/qdrant  (local)
```

```typescript
import { QdrantClient } from '@qdrant/js-client-rest';

const client = new QdrantClient({
  url: process.env.QDRANT_URL ?? 'http://localhost:6333',
  apiKey: process.env.QDRANT_API_KEY,
});

// Create collection
await client.createCollection('knowledge-base', {
  vectors: { size: 1536, distance: 'Cosine' },
  optimizers_config: { indexing_threshold: 10000 },
});

// Create payload index for filtering
await client.createPayloadIndex('knowledge-base', {
  field_name: 'source',
  field_schema: 'keyword',
});

// Upsert points
await client.upsert('knowledge-base', {
  points: chunks.map((chunk, i) => ({
    id: i,
    vector: embeddings[i],
    payload: {
      text: chunk,
      source: 'document.pdf',
      category: 'technical',
    },
  })),
});

// Search with filter
const results = await client.search('knowledge-base', {
  vector: query_embedding,
  limit: 10,
  score_threshold: 0.7,
  filter: {
    must: [
      { key: 'category', match: { value: 'technical' } },
    ],
  },
  with_payload: true,
});
```

---

## 6. Weaviate

```bash
npm install weaviate-client
```

```typescript
import weaviate, { WeaviateClient } from 'weaviate-client';

const client: WeaviateClient = await weaviate.connectToLocal();
// or: weaviate.connectToWeaviateCloud(process.env.WEAVIATE_URL, { authCredentials: ... })

// Create schema
await client.collections.create({
  name: 'Document',
  vectorizers: weaviate.configure.vectorizer.text2VecOpenAI({
    model: 'text-embedding-3-small',
  }),
  properties: [
    { name: 'text', dataType: weaviate.configure.dataType.TEXT },
    { name: 'source', dataType: weaviate.configure.dataType.TEXT },
    { name: 'category', dataType: weaviate.configure.dataType.TEXT },
  ],
});

const collection = client.collections.get('Document');

// Insert objects (auto-vectorized by Weaviate)
await collection.data.insertMany(
  chunks.map((chunk) => ({ text: chunk, source: 'doc.pdf', category: 'technical' }))
);

// Hybrid search (vector + BM25 keyword)
const results = await collection.query.hybrid('machine learning basics', {
  limit: 10,
  alpha: 0.75,   // 0 = pure keyword, 1 = pure vector, 0.75 = mostly semantic
  returnProperties: ['text', 'source'],
});
```

---

## 7. RAG Pipeline: Retrieve + Rerank + Generate

```typescript
// rag/pipeline.ts
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// Step 1: Retrieve
async function retrieve(query: string, top_k = 20): Promise<string[]> {
  const query_embedding = await embedText(query);
  const results = await index.query({ vector: query_embedding, topK: top_k, includeMetadata: true });
  return results.matches.map((m) => m.metadata!.text as string);
}

// Step 2: Rerank (Cohere or cross-encoder)
async function rerank(query: string, documents: string[], top_n = 5): Promise<string[]> {
  // Option A: Cohere reranker
  const { CohereClient } = await import('cohere-ai');
  const cohere = new CohereClient({ token: process.env.COHERE_API_KEY });
  const response = await cohere.rerank({
    model: 'rerank-english-v3.0',
    query,
    documents,
    topN: top_n,
  });
  return response.results.map((r) => documents[r.index]);
}

// Step 3: Generate
async function generate(query: string, contexts: string[]): Promise<string> {
  const context_text = contexts.map((c, i) => `[${i + 1}] ${c}`).join('\n\n');

  const response = await anthropic.messages.create({
    model: 'claude-opus-4-5',
    max_tokens: 1024,
    messages: [
      {
        role: 'user',
        content: `Answer the question based on the provided context. If the answer is not in the context, say so.

Context:
${context_text}

Question: ${query}`,
      },
    ],
  });

  return response.content[0].type === 'text' ? response.content[0].text : '';
}

// Full pipeline
export async function ragQuery(question: string): Promise<string> {
  const candidates = await retrieve(question, 20);
  const reranked = await rerank(question, candidates, 5);
  return generate(question, reranked);
}
```

---

## 8. Indexing Pipeline (Batch Processing)

```typescript
// scripts/index-documents.ts
async function indexDocuments(file_paths: string[]): Promise<void> {
  const BATCH_SIZE = 100;

  for (const file_path of file_paths) {
    const text = await readFile(file_path, 'utf-8');
    const chunks = chunkText(text, { chunk_size: 1000, chunk_overlap: 200 });

    // Process in batches (API rate limits)
    for (let i = 0; i < chunks.length; i += BATCH_SIZE) {
      const batch = chunks.slice(i, i + BATCH_SIZE);
      const embeddings = await embedBatch(batch);

      await index.upsert(
        batch.map((chunk, j) => ({
          id: `${path.basename(file_path)}_${i + j}`,
          values: embeddings[j],
          metadata: { text: chunk, source: file_path, chunk_index: i + j },
        }))
      );

      console.log(`Indexed ${i + batch.length}/${chunks.length} chunks from ${file_path}`);
      await sleep(200); // rate limit courtesy
    }
  }
}
```

---

## Reference Docs

- [Pinecone Docs](https://docs.pinecone.io/)
- [Qdrant Docs](https://qdrant.tech/documentation/)
- [Weaviate Docs](https://weaviate.io/developers/weaviate)
- [OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings)
- [Sentence Transformers](https://www.sbert.net/)
- [Cohere Rerank](https://docs.cohere.com/docs/rerank-2)
- [LangChain RAG](https://js.langchain.com/docs/tutorials/rag)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Vector DB nào bạn muốn dùng? (Pinecone / Qdrant / Weaviate / chưa chọn)"
2. "Embedding model: OpenAI (ada-002 / text-embedding-3) hay local (sentence-transformers)?"
3. "Use case: Q&A trên documents / semantic search / chatbot với knowledge base?"
4. "Ngôn ngữ documents: tiếng Anh / tiếng Việt / multilingual?"

Cung cấp pipeline code hoàn chỉnh và giải thích trade-off cho lựa chọn của họ.
