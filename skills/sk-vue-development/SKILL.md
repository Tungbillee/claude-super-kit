---
name: sk:vue-development
description: "Vue 3 Composition API, Pinia, Vue Router 4, TypeScript, Vitest — full production patterns"
version: 1.0.0
author: Claude Super Kit
type: capability
namespace: sk
category: frontend
last_updated: 2026-04-25
license: MIT
---

# sk:vue-development — Vue 3 Full-Stack Development

## When to Use

- Building Vue 3 components, composables, stores
- Setting up Pinia state management
- Configuring Vue Router 4 navigation guards
- Writing Vitest unit/component tests
- TypeScript + Vue SFC patterns

## Core Concepts

### Reactivity Primitives

```typescript
import { ref, reactive, computed, watch, watchEffect } from 'vue'

// ref → primitives, reactive → objects
const count = ref(0)
const state = reactive({ name: '', age: 0 })

// computed → derived, lazy, cached
const doubled = computed(() => count.value * 2)

// watch → explicit source, lazy by default
watch(count, (newVal, oldVal) => { /* side effect */ })
watch(() => state.name, (name) => { /* object property */ })

// watchEffect → auto-track, eager
watchEffect(() => { console.log(count.value) })
```

### SFC Structure (TypeScript)

```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { PropType } from 'vue'

// Props with type safety
const props = defineProps<{
  title: string
  items: string[]
  optional?: number
}>()

// Emits
const emit = defineEmits<{
  update: [value: string]
  close: []
}>()

// Local state
const is_loading = ref(false)
const filtered_items = computed(() =>
  props.items.filter(i => i.includes('test'))
)

onMounted(() => { /* init logic */ })
</script>

<template>
  <div>{{ title }}</div>
</template>
```

### Composables Pattern

```typescript
// composables/useAsyncData.ts
import { ref, type Ref } from 'vue'

export function useAsyncData<T>(fetcher: () => Promise<T>) {
  const data: Ref<T | null> = ref(null)
  const error = ref<Error | null>(null)
  const is_loading = ref(false)

  async function execute() {
    is_loading.value = true
    error.value = null
    try {
      data.value = await fetcher()
    } catch (e) {
      error.value = e as Error
    } finally {
      is_loading.value = false
    }
  }

  return { data, error, is_loading, execute }
}
```

### Pinia Store

```typescript
// stores/user.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useUserStore = defineStore('user', () => {
  // State
  const current_user = ref<User | null>(null)
  const is_authenticated = computed(() => current_user.value !== null)

  // Actions
  async function login(credentials: LoginInput) {
    try {
      current_user.value = await authApi.login(credentials)
    } catch (e) {
      throw new Error(`Login failed: ${(e as Error).message}`)
    }
  }

  function logout() {
    current_user.value = null
  }

  return { current_user, is_authenticated, login, logout }
})
```

### Vue Router 4 Patterns

```typescript
// router/index.ts
import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    component: () => import('@/layouts/DefaultLayout.vue'), // lazy
    children: [
      { path: '', component: () => import('@/pages/Home.vue') },
      {
        path: 'dashboard',
        component: () => import('@/pages/Dashboard.vue'),
        meta: { requires_auth: true }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Navigation guard
router.beforeEach(async (to) => {
  const user_store = useUserStore()
  if (to.meta.requires_auth && !user_store.is_authenticated) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
})
```

### TypeScript with Vue — Key Patterns

```typescript
// Typed provide/inject
import { provide, inject, type InjectionKey } from 'vue'

const API_KEY: InjectionKey<ApiService> = Symbol('api')
provide(API_KEY, new ApiService())
const api = inject(API_KEY) // ApiService | undefined

// Template refs
const input_ref = useTemplateRef<HTMLInputElement>('inputRef')

// defineModel (Vue 3.4+)
const model = defineModel<string>({ required: true })
```

### Vitest Testing

```typescript
// components/__tests__/Counter.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import Counter from '../Counter.vue'

describe('Counter', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('increments on click', async () => {
    const wrapper = mount(Counter)
    await wrapper.find('[data-testid="increment"]').trigger('click')
    expect(wrapper.find('[data-testid="count"]').text()).toBe('1')
  })

  it('emits update event', async () => {
    const wrapper = mount(Counter, { props: { initial: 5 } })
    await wrapper.find('button').trigger('click')
    expect(wrapper.emitted('update')).toBeTruthy()
    expect(wrapper.emitted('update')![0]).toEqual([6])
  })
})
```

### Vitest Config

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test-setup.ts']
  }
})
```

## Common Patterns

### Async Component with Suspense

```vue
<script setup>
const AsyncComp = defineAsyncComponent({
  loader: () => import('./HeavyComp.vue'),
  loadingComponent: LoadingSpinner,
  errorComponent: ErrorBoundary,
  delay: 200,
  timeout: 3000
})
</script>

<template>
  <Suspense>
    <AsyncComp />
    <template #fallback><LoadingSpinner /></template>
  </Suspense>
</template>
```

### v-model Custom Component

```vue
<!-- Child.vue -->
<script setup lang="ts">
const model = defineModel<string>({ required: true })
</script>
<template>
  <input :value="model" @input="model = $event.target.value" />
</template>
```

## Quick Decision Table

| Need | Solution |
|------|----------|
| Global state | Pinia store |
| Shared logic | Composable |
| Single-use logic | Setup function |
| Heavy computation | computed() |
| Side effect on change | watch() |
| Immediate side effect | watchEffect() |
| Cross-component event | mitt or store |

## User Interaction (MANDATORY)

This skill MUST follow [Interactive UI Protocol](../../rules/interactive-ui-protocol.md).
- Use `AskUserQuestion` tool for ALL user clarifications/choices
- Never ask via free-text prompts
- Each question: 2-4 predefined options + auto "Something else"

```javascript
AskUserQuestion({
  questions: [
    {
      question: "What type of Vue task?",
      header: "Task Type",
      options: [
        { label: "New component", description: "Create SFC with setup" },
        { label: "Pinia store", description: "State management" },
        { label: "Composable", description: "Reusable logic" },
        { label: "Router setup", description: "Navigation + guards" }
      ]
    },
    {
      question: "Using TypeScript?",
      header: "TypeScript",
      options: [
        { label: "Yes (strict)", description: "Full type safety" },
        { label: "Yes (loose)", description: "Types where helpful" },
        { label: "No (JS)", description: "Plain JavaScript" }
      ]
    }
  ]
})
```
