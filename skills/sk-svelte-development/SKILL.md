---
name: sk:svelte-development
description: Svelte 5 runes ($state, $derived, $effect, $props), stores (writable/readable/derived), animations (tweened/spring), transitions, context API. Vitest testing. Use for building reactive UIs with Svelte.
license: MIT
argument-hint: "[component|store|animation|test] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: frontend
  last_updated: "2026-04-25"
---

# Svelte Development Skill

Svelte 5 with runes-based reactivity, stores, animations, and testing patterns.

## When to Use

- Building reactive UI components with Svelte 5 runes
- Managing application state with stores
- Adding animations and transitions to UI elements
- Writing Svelte component tests with Vitest
- Integrating context API for component communication
- Migrating from Svelte 4 to Svelte 5 runes

## Svelte 5 Runes

### Core Runes

```svelte
<script>
  // State - reactive variable
  let count = $state(0);
  let user = $state({ name: 'Alice', age: 30 });

  // Derived - computed from state
  let doubled = $derived(count * 2);
  let full_name = $derived(`${user.first} ${user.last}`);

  // Effect - side effects
  $effect(() => {
    console.log('count changed:', count);
    return () => console.log('cleanup'); // optional cleanup
  });

  // Props - component inputs
  let { title, count: initial_count = 0 } = $props();
</script>

<button onclick={() => count++}>{count} × 2 = {doubled}</button>
```

### $state Deep Reactivity

```svelte
<script>
  let items = $state([]);
  let config = $state({ theme: 'dark', lang: 'vi' });

  // Direct mutation works (deep reactive)
  function addItem(item) {
    items.push(item); // triggers update
  }

  // $state.snapshot - non-reactive copy
  function saveState() {
    const snapshot = $state.snapshot(config);
    localStorage.setItem('config', JSON.stringify(snapshot));
  }

  // $state.is - identity check
  let a = $state({ x: 1 });
  let b = a;
  console.log($state.is(a, b)); // true
</script>
```

### $props and Bindable

```svelte
<!-- Child.svelte -->
<script>
  let {
    value = $bindable(0),  // two-way binding
    label,
    onchange,
    ...rest               // rest props
  } = $props();
</script>
<input bind:value={value} {...rest} />

<!-- Parent.svelte -->
<script>
  let val = $state(10);
</script>
<Child bind:value={val} label="Score" />
```

## Stores (Legacy - Still Supported)

```javascript
// stores.js
import { writable, readable, derived } from 'svelte/store';

// Writable store
export const count = writable(0);
count.update(n => n + 1);
count.set(0);

// Readable store (external data source)
export const time = readable(new Date(), (set) => {
  const interval = setInterval(() => set(new Date()), 1000);
  return () => clearInterval(interval); // cleanup
});

// Derived store
export const elapsed = derived(time, $time =>
  Math.round(($time - start) / 1000)
);

// Custom store with methods
function createCart() {
  const { subscribe, update } = writable([]);
  return {
    subscribe,
    add: (item) => update(items => [...items, item]),
    remove: (id) => update(items => items.filter(i => i.id !== id)),
    clear: () => update(() => [])
  };
}
export const cart = createCart();
```

```svelte
<!-- Auto-subscribe with $ prefix -->
<script>
  import { count, cart } from './stores.js';
</script>
<p>Count: {$count}</p>
<p>Cart items: {$cart.length}</p>
<button onclick={() => $count++}>Increment</button>
```

## Context API

```svelte
<!-- Parent.svelte -->
<script>
  import { setContext } from 'svelte';
  const theme = $state({ color: 'blue', size: 'md' });
  setContext('theme', { get theme() { return theme; } });
</script>

<!-- Deep Child.svelte -->
<script>
  import { getContext } from 'svelte';
  const { theme } = getContext('theme');
</script>
<div style="color: {theme.color}">Content</div>
```

## Animations & Transitions

```svelte
<script>
  import { tweened, spring } from 'svelte/motion';
  import { fade, fly, slide, scale } from 'svelte/transition';
  import { cubicOut } from 'svelte/easing';

  // Tweened (smooth interpolation)
  const progress = tweened(0, { duration: 400, easing: cubicOut });
  const position = spring({ x: 0, y: 0 }, { stiffness: 0.1, damping: 0.25 });

  let visible = $state(true);

  function animate() {
    progress.set(100);
    position.set({ x: 100, y: 50 });
  }
</script>

<!-- Transitions -->
{#if visible}
  <div transition:fade={{ duration: 300 }}>Fade</div>
  <div in:fly={{ y: 20 }} out:slide>Fly in, slide out</div>
{/if}

<!-- Animate directive (layout changes) -->
<div animate:flip={{ duration: 300 }}>...</div>

<!-- Progress bar with tweened -->
<progress value={$progress} max="100" />
```

## Component Patterns

```svelte
<!-- Snippet (Svelte 5 replacement for slots) -->
<script>
  let { header, children } = $props();
</script>

{@render header?.()}
{@render children?.()}

<!-- Usage -->
{#snippet header()}
  <h1>Title</h1>
{/snippet}
<Component {header}>
  Default content
</Component>
```

## Vitest Testing

```javascript
// component.test.js
import { render, fireEvent } from '@testing-library/svelte';
import { expect, test, vi } from 'vitest';
import Counter from './Counter.svelte';

test('increments count on click', async () => {
  const { getByText } = render(Counter, { props: { initial: 0 } });
  const btn = getByText('Count: 0');
  await fireEvent.click(btn);
  expect(getByText('Count: 1')).toBeTruthy();
});

// Store testing
import { get } from 'svelte/store';
import { cart } from './stores.js';

test('cart add/remove', () => {
  cart.add({ id: 1, name: 'Item' });
  expect(get(cart)).toHaveLength(1);
  cart.remove(1);
  expect(get(cart)).toHaveLength(0);
});
```

## Migration: Svelte 4 → Svelte 5

| Svelte 4 | Svelte 5 Runes |
|----------|----------------|
| `let x = 0` (reactive) | `let x = $state(0)` |
| `$: doubled = x * 2` | `let doubled = $derived(x * 2)` |
| `$: { console.log(x) }` | `$effect(() => { console.log(x) })` |
| `export let prop` | `let { prop } = $props()` |
| `<slot>` | `{@render children?.()}` |

## Performance Tips

- Use `$derived` over `$effect` for computed values (no side effects)
- `$effect.pre` runs before DOM update, `$effect` after
- Avoid deep state mutation in loops - batch updates
- Use `untrack()` to read state without creating dependency

## Resources

- Svelte 5 docs: https://svelte.dev/docs/svelte/overview
- Svelte REPL: https://svelte.dev/playground
- SvelteKit: https://kit.svelte.dev/

## User Interaction (MANDATORY)

When activated, ask:

1. **Task type:** "Bạn muốn làm gì với Svelte? (component/store/animation/test/migration)"
2. **Svelte version:** "Đang dùng Svelte 4 hay 5 (runes)?"
3. **Context:** "Mô tả ngắn về component/feature bạn cần xây dựng"

Then provide focused implementation with working code examples.
