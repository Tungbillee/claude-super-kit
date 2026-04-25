---
name: sk:i18n-localization
description: Internationalization and localization with i18next, react-i18next, ICU MessageFormat, pluralization, Intl API for date/currency/number, namespace strategies, lazy-loaded translations.
version: "1.0.0"
author: Claude Super Kit
namespace: sk
last_updated: "2026-04-25"
license: MIT
category: localization
argument-hint: "[i18n task or locale issue]"
---

# sk:i18n-localization

Complete guide for internationalization (i18n) and localization (l10n) in Node.js and React applications using i18next ecosystem.

## When to Use

- Setting up multi-language support in React or Node.js apps
- Handling pluralization, gender, and complex message formats
- Formatting dates, currencies, and numbers for different locales
- Organizing translation files with namespace strategies
- Implementing lazy-loaded translations for performance
- Migrating from react-intl or other i18n libraries to i18next

---

## 1. Setup: i18next + react-i18next

```bash
npm install i18next react-i18next i18next-http-backend i18next-browser-languagedetector
```

### Basic Configuration (src/i18n/index.ts)

```typescript
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import HttpBackend from 'i18next-http-backend';
import LanguageDetector from 'i18next-browser-languagedetector';

i18n
  .use(HttpBackend)
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    fallbackLng: 'en',
    supportedLngs: ['en', 'vi', 'ja', 'zh'],
    defaultNS: 'common',
    ns: ['common', 'auth', 'dashboard', 'errors'],
    backend: {
      loadPath: '/locales/{{lng}}/{{ns}}.json',
    },
    detection: {
      order: ['querystring', 'cookie', 'localStorage', 'navigator'],
      caches: ['localStorage', 'cookie'],
    },
    interpolation: {
      escapeValue: false, // React handles XSS
    },
    react: {
      useSuspense: true,
    },
  });

export default i18n;
```

### App Entry (main.tsx)

```tsx
import './i18n'; // import before App

ReactDOM.createRoot(document.getElementById('root')!).render(
  <Suspense fallback={<LoadingSpinner />}>
    <App />
  </Suspense>
);
```

---

## 2. Namespace Strategies

```
public/locales/
├── en/
│   ├── common.json      # shared: buttons, labels, dates
│   ├── auth.json        # login, register, password
│   ├── dashboard.json   # dashboard-specific
│   └── errors.json      # error messages
├── vi/
│   └── ...
```

```typescript
// Load namespace lazily per route
import { useTranslation } from 'react-i18next';

function DashboardPage() {
  const { t, ready } = useTranslation('dashboard', { useSuspense: false });
  if (!ready) return <Skeleton />;
  return <h1>{t('title')}</h1>;
}
```

---

## 3. Pluralization Rules

### Basic Plural Forms

```json
// en/common.json
{
  "items_count": "{{count}} item",
  "items_count_plural": "{{count}} items",
  "items_count_zero": "No items"
}
```

```typescript
t('items_count', { count: 0 });  // "No items"
t('items_count', { count: 1 });  // "1 item"
t('items_count', { count: 5 });  // "5 items"
```

### Complex Pluralization (Arabic, Russian, Polish)

```json
// ar/common.json — Arabic has 6 plural forms
{
  "items_count_zero": "لا عناصر",
  "items_count_one": "عنصر واحد",
  "items_count_two": "عنصران",
  "items_count_few": "{{count}} عناصر",
  "items_count_many": "{{count}} عنصرًا",
  "items_count_other": "{{count}} عنصر"
}
```

---

## 4. ICU MessageFormat

```bash
npm install i18next-icu
```

```typescript
import ICU from 'i18next-icu';

i18n.use(ICU).init({ /* ... */ });
```

```json
// en/common.json
{
  "greeting": "Hello, {name}!",
  "cart_summary": "{count, plural, =0 {Empty cart} one {# item} other {# items}}",
  "gender_msg": "{gender, select, male {He liked} female {She liked} other {They liked}} your post.",
  "deadline": "Due {date, date, medium} at {time, time, short}"
}
```

```typescript
t('cart_summary', { count: 3 });           // "3 items"
t('gender_msg', { gender: 'female' });     // "She liked your post."
t('deadline', { date: new Date(), time: new Date() });
```

---

## 5. Intl API: Dates, Currencies, Numbers

```typescript
// utils/formatters.ts
export const formatCurrency = (
  amount: number,
  currency: string,
  locale: string = 'en-US'
): string =>
  new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
  }).format(amount);

export const formatDate = (
  date: Date,
  locale: string,
  options: Intl.DateTimeFormatOptions = { dateStyle: 'medium' }
): string => new Intl.DateTimeFormat(locale, options).format(date);

export const formatNumber = (
  num: number,
  locale: string,
  options: Intl.NumberFormatOptions = {}
): string => new Intl.NumberFormat(locale, options).format(num);

// Usage
formatCurrency(1234567, 'VND', 'vi-VN');  // "1.234.567 ₫"
formatCurrency(1234.56, 'USD', 'en-US');   // "$1,234.56"
formatDate(new Date(), 'ja-JP', { dateStyle: 'full' });
formatNumber(1234567.89, 'de-DE');          // "1.234.567,89"
```

### i18next + Intl Integration

```typescript
// i18n/index.ts — custom formatter
i18n.init({
  interpolation: {
    format: (value, format, lng) => {
      if (value instanceof Date) {
        return new Intl.DateTimeFormat(lng, { dateStyle: format as any }).format(value);
      }
      if (format === 'currency' && typeof value === 'object') {
        return new Intl.NumberFormat(lng, {
          style: 'currency',
          currency: value.currency,
        }).format(value.amount);
      }
      return value;
    },
  },
});
```

---

## 6. Lazy-Loaded Translations (Code Splitting)

```typescript
// Dynamic import per route
const loadDashboardTranslations = async (lng: string) => {
  const module = await import(`../locales/${lng}/dashboard.json`);
  i18n.addResourceBundle(lng, 'dashboard', module.default, true, true);
};

// With React Router loader
export const dashboardLoader = async () => {
  const lng = i18n.language;
  if (!i18n.hasResourceBundle(lng, 'dashboard')) {
    await loadDashboardTranslations(lng);
  }
  return null;
};
```

---

## 7. Node.js Backend i18n

```typescript
import i18next from 'i18next';
import Backend from 'i18next-fs-backend';
import { LanguageDetector } from 'i18next-http-middleware';

i18next
  .use(Backend)
  .use(LanguageDetector)
  .init({
    backend: { loadPath: './locales/{{lng}}/{{ns}}.json' },
    fallbackLng: 'en',
    preload: ['en', 'vi'],
  });

// Express middleware
app.use(i18nextMiddleware.handle(i18next));

// In route handler
app.get('/greet', (req, res) => {
  res.json({ message: req.t('greeting', { name: 'World' }) });
});
```

---

## 8. TypeScript Type Safety

```typescript
// i18n/types.ts — generate types from translation files
import type en from '../public/locales/en/common.json';

declare module 'i18next' {
  interface CustomTypeOptions {
    defaultNS: 'common';
    resources: {
      common: typeof en;
    };
  }
}

// Now t() is fully typed:
t('items_count', { count: 3 }); // TS checks key exists
```

---

## 9. Testing i18n

```typescript
// test-utils/i18n.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

i18n.use(initReactI18next).init({
  lng: 'en',
  resources: {
    en: { common: { greeting: 'Hello, {{name}}!' } },
  },
});

// test/Component.test.tsx
import { I18nextProvider } from 'react-i18next';
render(<I18nextProvider i18n={i18n}><MyComponent /></I18nextProvider>);
```

---

## Reference Docs

- [i18next docs](https://www.i18next.com/)
- [react-i18next](https://react.i18next.com/)
- [ICU MessageFormat syntax](https://unicode-org.github.io/icu/userguide/format_parse/messages/)
- [MDN Intl API](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl)
- [CLDR Plural Rules](https://cldr.unicode.org/index/cldr-spec/plural-rules)

---

## User Interaction (MANDATORY)

When activated, ask the user:
1. "Bạn đang làm việc với framework nào? (React / Node.js Express / Next.js / full-stack)"
2. "Ngôn ngữ nào cần hỗ trợ? (vd: en, vi, ja, ar)"
3. "Bạn cần help với: setup ban đầu / pluralization / ICU format / Intl formatting / lazy loading / TypeScript types?"

Sau đó cung cấp code examples cụ thể cho use case của họ.
