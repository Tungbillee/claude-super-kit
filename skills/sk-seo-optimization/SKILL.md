---
name: sk:seo-optimization
description: SEO best practices - sitemap.xml generation, robots.txt, Schema.org JSON-LD structured data (Article/Product/Organization/BreadcrumbList), Open Graph, Twitter Cards, canonical URLs, hreflang for multi-language sites.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: web
argument-hint: "[SEO task or structured data type]"
---

# sk:seo-optimization

Complete guide for technical SEO implementation in modern web applications (Next.js, Astro, plain HTML).

## When to Use

- Generating sitemap.xml and robots.txt
- Adding Schema.org JSON-LD structured data
- Implementing Open Graph and Twitter Card meta tags
- Setting canonical URLs to avoid duplicate content
- Configuring hreflang for multi-language/multi-region sites
- Auditing and improving Core Web Vitals impact on SEO

---

## 1. robots.txt

```txt
# public/robots.txt
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /api/
Disallow: /_next/
Disallow: /private/

# Specific bots
User-agent: GPTBot
Disallow: /

Sitemap: https://example.com/sitemap.xml
Sitemap: https://example.com/sitemap-news.xml
```

---

## 2. Sitemap XML Generation

### Static sitemap.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
  <url>
    <loc>https://example.com/</loc>
    <lastmod>2026-04-25</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
    <!-- hreflang alternates -->
    <xhtml:link rel="alternate" hreflang="en" href="https://example.com/"/>
    <xhtml:link rel="alternate" hreflang="vi" href="https://example.com/vi/"/>
  </url>
</urlset>
```

### Dynamic Sitemap (Next.js App Router)

```typescript
// app/sitemap.ts
import { MetadataRoute } from 'next';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base_url = 'https://example.com';

  // Fetch dynamic routes from DB/CMS
  const posts = await fetchAllPosts(); // your data fetcher

  const post_entries: MetadataRoute.Sitemap = posts.map((post) => ({
    url: `${base_url}/blog/${post.slug}`,
    lastModified: new Date(post.updated_at),
    changeFrequency: 'weekly',
    priority: 0.8,
    alternates: {
      languages: {
        en: `${base_url}/blog/${post.slug}`,
        vi: `${base_url}/vi/blog/${post.slug}`,
      },
    },
  }));

  return [
    { url: base_url, lastModified: new Date(), priority: 1.0, changeFrequency: 'daily' },
    { url: `${base_url}/about`, priority: 0.5, changeFrequency: 'monthly' },
    ...post_entries,
  ];
}
```

### Sitemap Index (large sites)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://example.com/sitemap-pages.xml</loc>
    <lastmod>2026-04-25</lastmod>
  </sitemap>
  <sitemap>
    <loc>https://example.com/sitemap-posts.xml</loc>
    <lastmod>2026-04-25</lastmod>
  </sitemap>
</sitemapindex>
```

---

## 3. Schema.org JSON-LD Structured Data

### Article

```typescript
// components/ArticleJsonLd.tsx
interface ArticleJsonLdProps {
  title: string;
  description: string;
  url: string;
  image: string;
  published_at: string;
  modified_at: string;
  author_name: string;
}

export function ArticleJsonLd({
  title, description, url, image,
  published_at, modified_at, author_name,
}: ArticleJsonLdProps) {
  const json_ld = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: title,
    description,
    url,
    image: { '@type': 'ImageObject', url: image },
    datePublished: published_at,
    dateModified: modified_at,
    author: { '@type': 'Person', name: author_name },
    publisher: {
      '@type': 'Organization',
      name: 'Example Corp',
      logo: { '@type': 'ImageObject', url: 'https://example.com/logo.png' },
    },
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(json_ld) }}
    />
  );
}
```

### Product

```typescript
const product_json_ld = {
  '@context': 'https://schema.org',
  '@type': 'Product',
  name: 'Product Name',
  description: 'Product description',
  image: ['https://example.com/product-1.jpg'],
  brand: { '@type': 'Brand', name: 'Brand Name' },
  sku: 'SKU-12345',
  offers: {
    '@type': 'Offer',
    url: 'https://example.com/product',
    priceCurrency: 'USD',
    price: '29.99',
    priceValidUntil: '2026-12-31',
    itemCondition: 'https://schema.org/NewCondition',
    availability: 'https://schema.org/InStock',
  },
  aggregateRating: {
    '@type': 'AggregateRating',
    ratingValue: '4.5',
    reviewCount: '128',
  },
};
```

### Organization

```typescript
const org_json_ld = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'Example Corp',
  url: 'https://example.com',
  logo: 'https://example.com/logo.png',
  contactPoint: {
    '@type': 'ContactPoint',
    telephone: '+1-555-000-0000',
    contactType: 'customer service',
    availableLanguage: ['English', 'Vietnamese'],
  },
  sameAs: [
    'https://www.facebook.com/example',
    'https://twitter.com/example',
    'https://www.linkedin.com/company/example',
  ],
};
```

### BreadcrumbList

```typescript
function buildBreadcrumbJsonLd(
  crumbs: Array<{ name: string; url: string }>
) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: crumbs.map((crumb, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: crumb.name,
      item: crumb.url,
    })),
  };
}

// Usage
buildBreadcrumbJsonLd([
  { name: 'Home', url: 'https://example.com' },
  { name: 'Blog', url: 'https://example.com/blog' },
  { name: 'Article Title', url: 'https://example.com/blog/article' },
]);
```

---

## 4. Open Graph + Twitter Cards

### Next.js Metadata API

```typescript
// app/blog/[slug]/page.tsx
import { Metadata } from 'next';

export async function generateMetadata({ params }): Promise<Metadata> {
  const post = await fetchPost(params.slug);
  const base_url = 'https://example.com';

  return {
    title: post.title,
    description: post.excerpt,
    alternates: {
      canonical: `${base_url}/blog/${post.slug}`,
      languages: {
        'en-US': `${base_url}/blog/${post.slug}`,
        'vi-VN': `${base_url}/vi/blog/${post.slug}`,
      },
    },
    openGraph: {
      type: 'article',
      title: post.title,
      description: post.excerpt,
      url: `${base_url}/blog/${post.slug}`,
      siteName: 'Example Blog',
      images: [{ url: post.cover_image, width: 1200, height: 630, alt: post.title }],
      publishedTime: post.published_at,
      modifiedTime: post.updated_at,
      authors: [post.author.name],
      locale: 'en_US',
    },
    twitter: {
      card: 'summary_large_image',
      title: post.title,
      description: post.excerpt,
      images: [post.cover_image],
      creator: '@authorhandle',
      site: '@sitehandle',
    },
  };
}
```

### Plain HTML Meta Tags

```html
<!-- Open Graph -->
<meta property="og:type" content="article" />
<meta property="og:title" content="Page Title" />
<meta property="og:description" content="Page description" />
<meta property="og:image" content="https://example.com/og-image.jpg" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:url" content="https://example.com/page" />
<meta property="og:site_name" content="Site Name" />

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="Page Title" />
<meta name="twitter:description" content="Page description" />
<meta name="twitter:image" content="https://example.com/twitter-image.jpg" />
```

---

## 5. Canonical URLs

```typescript
// Next.js App Router — per page
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://example.com/definitive-url',
  },
};

// Avoid duplicate content from query params
// https://example.com/products?sort=price → canonical → https://example.com/products
```

```html
<!-- Plain HTML -->
<link rel="canonical" href="https://example.com/definitive-url" />
```

---

## 6. hreflang (Multi-language/Multi-region)

```typescript
// Next.js — all language alternates on each page
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://example.com/en/about',
    languages: {
      'en-US': 'https://example.com/en/about',
      'vi-VN': 'https://example.com/vi/about',
      'ja-JP': 'https://example.com/ja/about',
      'x-default': 'https://example.com/en/about',
    },
  },
};
```

```html
<!-- Plain HTML — must be on ALL alternate pages -->
<link rel="alternate" hreflang="en-US" href="https://example.com/en/about" />
<link rel="alternate" hreflang="vi-VN" href="https://example.com/vi/about" />
<link rel="alternate" hreflang="x-default" href="https://example.com/en/about" />
```

---

## 7. SEO Audit Checklist

```bash
# Validate structured data
curl https://validator.schema.org/

# Check robots.txt
curl https://example.com/robots.txt

# Validate sitemap
curl https://example.com/sitemap.xml | xmllint --noout -

# Lighthouse CLI audit
npx lighthouse https://example.com --output=json --only-categories=seo
```

---

## Reference Docs

- [Google Search Central](https://developers.google.com/search/docs)
- [Schema.org](https://schema.org/)
- [Rich Results Test](https://search.google.com/test/rich-results)
- [Open Graph Protocol](https://ogp.me/)
- [Twitter Card Validator](https://cards-dev.twitter.com/validator)
- [Next.js Metadata API](https://nextjs.org/docs/app/api-reference/functions/generate-metadata)

---

## User Interaction (MANDATORY)

Khi được kích hoạt, hỏi người dùng:
1. "Bạn đang dùng framework nào? (Next.js App Router / Pages Router / Astro / plain HTML)"
2. "Bạn cần implement: sitemap / robots.txt / JSON-LD structured data / Open Graph / canonical / hreflang?"
3. "Nếu JSON-LD, loại schema nào? (Article / Product / Organization / BreadcrumbList / FAQ / HowTo)"

Sau đó cung cấp code snippet sẵn sàng copy-paste cho framework và use case cụ thể.
