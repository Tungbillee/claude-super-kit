---
name: sk:elasticsearch
description: Elasticsearch index design (mappings/analyzers), Query DSL (bool/match/term/range), aggregations (terms/date_histogram/nested), pagination (search_after), performance tuning, Kibana basics.
license: MIT
argument-hint: "[mapping|query|aggregation|pagination|performance|kibana] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: database
  last_updated: "2026-04-25"
---

# Elasticsearch Skill

Full-text search, analytics, and log analysis with Elasticsearch 8.x.

## When to Use

- Full-text search with relevance ranking
- Log aggregation and analysis (ELK stack)
- Complex analytics with aggregations
- Faceted search (filters + counts)
- Autocomplete and suggestions
- Geospatial queries

## Index Design

### Mappings

```json
PUT /products
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "vietnamese_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "asciifolding", "stop"]
        },
        "autocomplete_analyzer": {
          "type": "custom",
          "tokenizer": "edge_ngram_tokenizer",
          "filter": ["lowercase"]
        }
      },
      "tokenizer": {
        "edge_ngram_tokenizer": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 10,
          "token_chars": ["letter", "digit"]
        }
      }
    }
  },
  "mappings": {
    "dynamic": "strict",
    "properties": {
      "id":          { "type": "keyword" },
      "name":        { "type": "text", "analyzer": "vietnamese_analyzer",
                       "fields": { "keyword": { "type": "keyword" },
                                   "suggest": { "type": "text", "analyzer": "autocomplete_analyzer" } } },
      "description": { "type": "text", "analyzer": "vietnamese_analyzer" },
      "price":       { "type": "double" },
      "category":    { "type": "keyword" },
      "tags":        { "type": "keyword" },
      "in_stock":    { "type": "boolean" },
      "created_at":  { "type": "date" },
      "location":    { "type": "geo_point" },
      "attributes":  {
        "type": "nested",
        "properties": {
          "key":   { "type": "keyword" },
          "value": { "type": "keyword" }
        }
      }
    }
  }
}
```

## Query DSL

### Bool Query (main building block)

```json
GET /products/_search
{
  "query": {
    "bool": {
      "must": [
        { "match": { "name": { "query": "laptop gaming", "operator": "and" } } }
      ],
      "filter": [
        { "term":  { "in_stock": true } },
        { "terms": { "category": ["electronics", "computers"] } },
        { "range": { "price": { "gte": 500, "lte": 2000 } } },
        { "range": { "created_at": { "gte": "now-30d/d" } } }
      ],
      "should": [
        { "term": { "tags": "gaming" } },
        { "term": { "tags": "rtx4080" } }
      ],
      "must_not": [
        { "term": { "category": "refurbished" } }
      ],
      "minimum_should_match": 1,
      "boost": 1.5
    }
  }
}
```

### Match Queries

```json
// match - full-text, analyzed
{ "match": { "description": { "query": "red shoes", "fuzziness": "AUTO" } } }

// match_phrase - exact phrase
{ "match_phrase": { "name": "apple macbook pro" } }

// multi_match - search across fields
{
  "multi_match": {
    "query": "gaming laptop",
    "fields": ["name^3", "description", "tags^2"],
    "type": "best_fields",
    "tie_breaker": 0.3
  }
}

// fuzzy - typo tolerance
{ "fuzzy": { "name": { "value": "laptob", "fuzziness": 2 } } }
```

### Nested Query

```json
GET /products/_search
{
  "query": {
    "nested": {
      "path": "attributes",
      "query": {
        "bool": {
          "must": [
            { "term": { "attributes.key": "color" } },
            { "term": { "attributes.value": "red" } }
          ]
        }
      },
      "score_mode": "avg"
    }
  }
}
```

## Aggregations

### Terms & Date Histogram

```json
GET /orders/_search
{
  "size": 0,
  "aggs": {
    "by_status": {
      "terms": {
        "field": "status",
        "size": 10,
        "order": { "_count": "desc" }
      }
    },
    "revenue_over_time": {
      "date_histogram": {
        "field": "created_at",
        "calendar_interval": "month",
        "time_zone": "Asia/Ho_Chi_Minh",
        "min_doc_count": 0
      },
      "aggs": {
        "total_revenue": { "sum": { "field": "amount" } },
        "avg_order":     { "avg": { "field": "amount" } },
        "order_count":   { "value_count": { "field": "id" } }
      }
    },
    "price_ranges": {
      "range": {
        "field": "price",
        "ranges": [
          { "to": 100 },
          { "from": 100, "to": 500 },
          { "from": 500 }
        ]
      }
    }
  }
}
```

### Nested Aggregation

```json
{
  "aggs": {
    "attributes": {
      "nested": { "path": "attributes" },
      "aggs": {
        "color_values": {
          "filter": { "term": { "attributes.key": "color" } },
          "aggs": {
            "colors": { "terms": { "field": "attributes.value", "size": 20 } }
          }
        }
      }
    }
  }
}
```

## Pagination

### search_after (recommended for deep pagination)

```json
// First page
GET /products/_search
{
  "size": 20,
  "sort": [
    { "created_at": "desc" },
    { "_id": "asc" }          // tiebreaker - must be unique
  ],
  "query": { "match_all": {} }
}

// Next page - use last hit's sort values
GET /products/_search
{
  "size": 20,
  "sort": [
    { "created_at": "desc" },
    { "_id": "asc" }
  ],
  "search_after": ["2024-01-15T10:30:00.000Z", "abc123"],
  "query": { "match_all": {} }
}
```

### Point in Time (PIT) for consistent pagination

```json
// Create PIT
POST /products/_pit?keep_alive=5m
// Returns: { "id": "pit_id_here" }

// Search with PIT
{ "pit": { "id": "pit_id_here", "keep_alive": "5m" },
  "sort": [{ "@timestamp": "asc" }, { "_id": "asc" }],
  "search_after": [...] }

// Delete PIT when done
DELETE /_pit { "id": "pit_id_here" }
```

## Performance Tuning

```json
// 1. Use filter context (no scoring, cacheable)
// ✓ filter instead of must for non-scoring conditions
{ "bool": { "filter": [{ "term": { "status": "active" } }] } }

// 2. Source filtering - return only needed fields
{ "_source": ["id", "name", "price"], "query": {...} }

// 3. Index settings for bulk indexing
PUT /products/_settings
{
  "refresh_interval": "30s",   // default 1s, increase for bulk
  "number_of_replicas": 0      // 0 during initial load
}

// 4. Shard sizing: aim for 10-50GB per shard
// Check: GET /_cat/indices?v&s=store.size:desc

// 5. Index lifecycle management (ILM)
PUT /_ilm/policy/logs-policy
{
  "policy": {
    "phases": {
      "hot":    { "min_age": "0ms", "actions": { "rollover": { "max_size": "50GB", "max_age": "7d" } } },
      "warm":   { "min_age": "7d",  "actions": { "shrink": { "number_of_shards": 1 }, "forcemerge": { "max_num_segments": 1 } } },
      "delete": { "min_age": "90d", "actions": { "delete": {} } }
    }
  }
}
```

## Node.js Client

```typescript
import { Client } from '@elastic/elasticsearch';

const es = new Client({
  node: 'https://localhost:9200',
  auth: { username: 'elastic', password: process.env.ES_PASSWORD! },
  tls: { ca: fs.readFileSync('./certs/ca.crt') }
});

// Index document
await es.index({ index: 'products', id: product.id, document: product });
await es.indices.refresh({ index: 'products' }); // make immediately searchable

// Search with TypeScript types
const result = await es.search<Product>({
  index: 'products',
  query: { match: { name: 'laptop' } },
  size: 20,
});
const products = result.hits.hits.map(h => h._source!);

// Bulk indexing
const operations = products.flatMap(p => [
  { index: { _index: 'products', _id: p.id } },
  p
]);
const { errors } = await es.bulk({ operations, refresh: true });
if (errors) { /* handle failed items */ }
```

## Resources

- Query DSL: https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html
- Aggregations: https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations.html
- Node.js client: https://www.elastic.co/guide/en/elasticsearch/client/javascript-api/current

## User Interaction (MANDATORY)

When activated, ask:

1. **Use case:** "Search hay analytics? (full-text search/log analysis/faceted search/aggregation)"
2. **Data:** "Mô tả schema data và approximate document count"
3. **Query type:** "Bạn đang query gì? Paste query hiện tại nếu có vấn đề về performance"

Then provide optimized query with mapping recommendations.
