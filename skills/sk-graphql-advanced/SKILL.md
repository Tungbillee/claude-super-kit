---
name: sk:graphql-advanced
description: Apollo Server v4, schema stitching, Apollo Federation, subscriptions (WebSocket), DataLoader pattern, error handling, security (depth limits, query whitelisting, persisted queries).
license: MIT
argument-hint: "[schema|federation|subscriptions|dataloader|security|errors] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: api
  last_updated: "2026-04-25"
---

# GraphQL Advanced Skill

Production GraphQL with Apollo Server v4, federation, real-time subscriptions, and security.

## When to Use

- Building flexible APIs with Apollo Server v4
- Microservices unified with Apollo Federation
- Real-time data with GraphQL subscriptions
- Fixing N+1 query problems with DataLoader
- Securing GraphQL APIs against abuse
- Distributed schema composition

## Apollo Server v4 Setup

```typescript
import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';
import { makeExecutableSchema } from '@graphql-tools/schema';

const type_defs = `#graphql
  type Query {
    user(id: ID!): User
    posts(filter: PostFilter, pagination: PaginationInput): PostConnection!
  }
  type Mutation {
    createPost(input: CreatePostInput!): Post!
    updatePost(id: ID!, input: UpdatePostInput!): Post!
  }
  type Subscription {
    postAdded(channel_id: ID!): Post!
  }
  type User {
    id: ID!
    name: String!
    email: String!
    posts: [Post!]!
  }
  type Post {
    id: ID!
    title: String!
    author: User!
    comments: [Comment!]!
    created_at: String!
  }
  input CreatePostInput { title: String!, body: String!, channel_id: ID! }
  input PostFilter { status: PostStatus, author_id: ID }
  input PaginationInput { first: Int, after: String, last: Int, before: String }
  type PostConnection { edges: [PostEdge!]!, page_info: PageInfo! }
  type PostEdge { node: Post!, cursor: String! }
  type PageInfo { has_next_page: Boolean!, end_cursor: String }
  enum PostStatus { DRAFT PUBLISHED ARCHIVED }
`;

const server = new ApolloServer({
  schema: makeExecutableSchema({ typeDefs: type_defs, resolvers }),
  plugins: [
    ApolloServerPluginDrainHttpServer({ httpServer }),
    process.env.NODE_ENV === 'production'
      ? ApolloServerPluginLandingPageDisabled()
      : ApolloServerPluginLandingPageLocalDefault(),
  ],
  formatError: (err, original) => {
    // Never expose internal errors in production
    if (err.extensions?.code === 'INTERNAL_SERVER_ERROR' && process.env.NODE_ENV === 'production') {
      return new GraphQLError('Internal server error', { extensions: { code: 'INTERNAL_SERVER_ERROR' } });
    }
    return err;
  },
});
```

## Resolvers & Context

```typescript
interface Context {
  user: { id: string; role: string } | null;
  loaders: ReturnType<typeof createLoaders>;
}

const resolvers = {
  Query: {
    user: async (_: unknown, { id }: { id: string }, ctx: Context) => {
      if (!ctx.user) throw new GraphQLError('Not authenticated', {
        extensions: { code: 'UNAUTHENTICATED' }
      });
      return ctx.loaders.user.load(id);
    },
    posts: async (_: unknown, { filter, pagination }: PostsArgs, ctx: Context) => {
      return postService.findPaginated(filter, pagination);
    },
  },
  Mutation: {
    createPost: async (_: unknown, { input }: { input: CreatePostInput }, ctx: Context) => {
      if (!ctx.user) throw new GraphQLError('Not authenticated', {
        extensions: { code: 'UNAUTHENTICATED' }
      });
      return postService.create({ ...input, author_id: ctx.user.id });
    },
  },
  // Field resolvers (for derived/joined data)
  Post: {
    author: (post: Post, _: unknown, ctx: Context) => ctx.loaders.user.load(post.author_id),
    comments: (post: Post, _: unknown, ctx: Context) => ctx.loaders.comments.load(post.id),
  },
  User: {
    posts: (user: User, _: unknown, ctx: Context) => ctx.loaders.userPosts.load(user.id),
  }
};

// Context factory
async function createContext({ req }: { req: Request }): Promise<Context> {
  const token = req.headers.authorization?.replace('Bearer ', '');
  const user = token ? await auth.verifyToken(token) : null;
  return { user, loaders: createLoaders() };
}
```

## DataLoader (N+1 Fix)

```typescript
import DataLoader from 'dataloader';

// WITHOUT DataLoader: 1 query for posts + N queries for each author = N+1 problem
// WITH DataLoader: batch all user loads into 1 query

function createLoaders() {
  return {
    user: new DataLoader<string, User>(async (ids) => {
      const users = await db.user.findMany({ where: { id: { in: ids as string[] } } });
      // Must return in same order as input ids
      const user_map = new Map(users.map(u => [u.id, u]));
      return ids.map(id => user_map.get(id) ?? new Error(`User ${id} not found`));
    }),

    comments: new DataLoader<string, Comment[]>(async (post_ids) => {
      const comments = await db.comment.findMany({
        where: { post_id: { in: post_ids as string[] } }
      });
      const by_post = new Map<string, Comment[]>();
      comments.forEach(c => {
        const arr = by_post.get(c.post_id) ?? [];
        arr.push(c);
        by_post.set(c.post_id, arr);
      });
      return post_ids.map(id => by_post.get(id) ?? []);
    }, {
      cache: true,          // default, dedup within request
      maxBatchSize: 100,    // limit batch size
    }),

    userPosts: new DataLoader<string, Post[]>(async (user_ids) => {
      const posts = await db.post.findMany({
        where: { author_id: { in: user_ids as string[] }, status: 'PUBLISHED' }
      });
      const by_user = new Map<string, Post[]>();
      posts.forEach(p => {
        const arr = by_user.get(p.author_id) ?? [];
        arr.push(p);
        by_user.set(p.author_id, arr);
      });
      return user_ids.map(id => by_user.get(id) ?? []);
    }),
  };
}
// NEW loaders per request (scoped cache, no cross-request data leak)
```

## Subscriptions (WebSocket)

```typescript
import { WebSocketServer } from 'ws';
import { useServer } from 'graphql-ws/lib/use/ws';
import { PubSub } from 'graphql-subscriptions';

const pubsub = new PubSub(); // use Redis PubSub for multi-instance

const resolvers = {
  Subscription: {
    postAdded: {
      subscribe: async function* (_: unknown, { channel_id }: { channel_id: string }, ctx: Context) {
        if (!ctx.user) throw new GraphQLError('Not authenticated', {
          extensions: { code: 'UNAUTHENTICATED' }
        });
        // AsyncIterator from PubSub
        const iterator = pubsub.asyncIterator(`POST_ADDED:${channel_id}`);
        for await (const payload of iterator) {
          yield payload;
        }
      },
      resolve: (payload: { postAdded: Post }) => payload.postAdded,
    }
  },
  Mutation: {
    createPost: async (_: unknown, { input }: any, ctx: Context) => {
      const post = await postService.create(input);
      pubsub.publish(`POST_ADDED:${input.channel_id}`, { postAdded: post });
      return post;
    }
  }
};

// WebSocket server setup
const ws_server = new WebSocketServer({ server: http_server, path: '/graphql' });
const cleanup = useServer({
  schema,
  context: async (ctx) => {
    const token = ctx.connectionParams?.authorization as string;
    const user = token ? await auth.verifyToken(token.replace('Bearer ', '')) : null;
    return { user, loaders: createLoaders() };
  },
  onDisconnect: (ctx) => console.log('Client disconnected'),
}, ws_server);
```

## Apollo Federation

```typescript
// products subgraph - services/products/schema.ts
import { buildSubgraphSchema } from '@apollo/subgraph';
import gql from 'graphql-tag';

const type_defs = gql`
  extend schema @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key", "@external", "@requires"])

  type Product @key(fields: "id") {
    id: ID!
    name: String!
    price: Float!
  }

  type Query {
    product(id: ID!): Product
    products: [Product!]!
  }
`;

const resolvers = {
  Product: {
    __resolveReference: async (ref: { id: string }) => {
      return productService.findById(ref.id);
    }
  },
  Query: { product: (_, { id }) => productService.findById(id) }
};

export const schema = buildSubgraphSchema({ typeDefs: type_defs, resolvers });

// reviews subgraph - references Product without owning it
const reviews_type_defs = gql`
  extend schema @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key", "@external"])

  type Product @key(fields: "id", resolvable: false) {
    id: ID! @external
  }
  type Review {
    id: ID!
    rating: Int!
    product: Product!
  }
`;
```

```yaml
# router.yaml (Apollo Router)
supergraph:
  listen: 0.0.0.0:4000
subgraphs:
  products:
    routing_url: http://products-service:4001/graphql
  reviews:
    routing_url: http://reviews-service:4002/graphql
```

## Security

```typescript
import depthLimit from 'graphql-depth-limit';
import { createComplexityLimitRule } from 'graphql-validation-complexity';

const server = new ApolloServer({
  schema,
  validationRules: [
    depthLimit(7),                              // max query depth
    createComplexityLimitRule(1000, {           // max complexity score
      scalarCost: 1,
      objectCost: 2,
      listFactor: 10,
    }),
  ],
  // Persisted queries (whitelist approach)
  cache: new InMemoryLRUCache(),
});

// Persisted queries with APQ (Automatic Persisted Queries)
// Client sends hash first, server caches full query
// Prevents arbitrary query injection in production

// Disable introspection in production
const server = new ApolloServer({
  schema,
  introspection: process.env.NODE_ENV !== 'production',
  plugins: [
    {
      async requestDidStart() {
        return {
          async didResolveOperation({ request, document }) {
            // Check against allowlist
            if (process.env.NODE_ENV === 'production') {
              const op_name = request.operationName;
              if (!ALLOWED_OPERATIONS.has(op_name ?? '')) {
                throw new GraphQLError('Operation not allowed');
              }
            }
          }
        };
      }
    }
  ]
});
```

## Error Handling Patterns

```typescript
// Custom error classes
class ValidationError extends GraphQLError {
  constructor(message: string, field: string) {
    super(message, { extensions: { code: 'VALIDATION_ERROR', field } });
  }
}
class NotFoundError extends GraphQLError {
  constructor(resource: string, id: string) {
    super(`${resource} ${id} not found`, { extensions: { code: 'NOT_FOUND' } });
  }
}

// Error codes: UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, VALIDATION_ERROR, INTERNAL_SERVER_ERROR
```

## Resources

- Apollo Server v4: https://www.apollographql.com/docs/apollo-server
- Apollo Federation v2: https://www.apollographql.com/docs/federation
- DataLoader: https://github.com/graphql/dataloader
- graphql-ws: https://github.com/enisdenjo/graphql-ws

## User Interaction (MANDATORY)

When activated, ask:

1. **Problem:** "Bạn đang gặp vấn đề gì? (N+1/schema design/federation setup/subscriptions/security)"
2. **Scale:** "Single service hay multiple subgraphs?"
3. **Tech stack:** "Apollo Server version? Express/Fastify/standalone?"

Then provide targeted implementation with security and performance considerations.
