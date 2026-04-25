---
name: sk:firebase-realtime
description: Firestore queries & real-time listeners (onSnapshot), security rules, Firebase Auth, Cloud Functions, offline persistence, Firestore vs RTDB decision guide. Google Firebase platform.
license: MIT
argument-hint: "[firestore|auth|functions|rules|offline|rtdb] [task]"
metadata:
  author: Claude Super Kit
  version: "1.0.0"
  namespace: sk
  category: database
  last_updated: "2026-04-25"
---

# Firebase Realtime Skill

Firestore, Auth, Cloud Functions, and real-time data for modern web/mobile apps.

## When to Use

- Real-time collaborative apps (chat, live dashboards)
- Mobile apps needing offline support
- Rapid prototyping with serverless backend
- Firebase Auth with social login
- Event-driven backend with Cloud Functions

## Firestore Queries

```typescript
import { initializeApp } from 'firebase/app';
import {
  getFirestore, collection, doc, query, where, orderBy, limit,
  startAfter, getDocs, getDoc, addDoc, setDoc, updateDoc, deleteDoc,
  serverTimestamp, increment, arrayUnion, arrayRemove, Timestamp
} from 'firebase/firestore';

const db = getFirestore(app);

// Read single document
const user_doc = await getDoc(doc(db, 'users', user_id));
if (user_doc.exists()) {
  const user = { id: user_doc.id, ...user_doc.data() };
}

// Query with filters
const q = query(
  collection(db, 'posts'),
  where('status', '==', 'published'),
  where('tags', 'array-contains', 'typescript'),
  orderBy('created_at', 'desc'),
  limit(20)
);
const snapshot = await getDocs(q);
const posts = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));

// Pagination with cursor
const last_doc = snapshot.docs[snapshot.docs.length - 1];
const next_q = query(
  collection(db, 'posts'),
  where('status', '==', 'published'),
  orderBy('created_at', 'desc'),
  startAfter(last_doc),
  limit(20)
);

// Compound queries (requires composite index)
const filtered = query(
  collection(db, 'orders'),
  where('user_id', '==', user_id),
  where('status', 'in', ['pending', 'processing']),
  orderBy('created_at', 'desc')
);
```

## Real-time Listeners

```typescript
import { onSnapshot, onSnapshotsInSync } from 'firebase/firestore';

// Single document listener
const unsubscribe = onSnapshot(
  doc(db, 'rooms', room_id),
  (snapshot) => {
    if (snapshot.exists()) {
      setRoom({ id: snapshot.id, ...snapshot.data() });
    }
  },
  (error) => console.error('Listen error:', error)
);

// Collection listener with metadata
const unsubscribe_list = onSnapshot(
  query(collection(db, 'messages'), where('room_id', '==', room_id), orderBy('sent_at')),
  { includeMetadataChanges: true },
  (snapshot) => {
    snapshot.docChanges().forEach(change => {
      if (change.type === 'added') addMessage(change.doc);
      if (change.type === 'modified') updateMessage(change.doc);
      if (change.type === 'removed') removeMessage(change.doc.id);
    });
    // Check if data is from local cache or server
    if (!snapshot.metadata.fromCache) setLastSync(new Date());
  }
);

// React hook pattern
function useDocument<T>(path: string) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(doc(db, path), snap => {
      setData(snap.exists() ? { id: snap.id, ...snap.data() } as T : null);
      setLoading(false);
    });
    return unsub; // cleanup
  }, [path]);

  return { data, loading };
}
```

## Writes & Transactions

```typescript
import { runTransaction, writeBatch } from 'firebase/firestore';

// Atomic transaction
await runTransaction(db, async (transaction) => {
  const account_ref = doc(db, 'accounts', account_id);
  const account = await transaction.get(account_ref);

  if (!account.exists()) throw new Error('Account not found');
  const balance = account.data().balance;
  if (balance < amount) throw new Error('Insufficient funds');

  transaction.update(account_ref, { balance: increment(-amount) });
  transaction.set(doc(collection(db, 'transactions')), {
    amount, account_id, type: 'debit', created_at: serverTimestamp()
  });
});

// Batch writes (up to 500 ops)
const batch = writeBatch(db);
items.forEach(item => {
  batch.set(doc(collection(db, 'items')), { ...item, created_at: serverTimestamp() });
});
batch.update(doc(db, 'stats', 'global'), { item_count: increment(items.length) });
await batch.commit();

// Field updates
await updateDoc(doc(db, 'users', user_id), {
  'profile.bio': 'Updated bio',      // nested field
  tags: arrayUnion('firebase'),       // add to array (no duplicates)
  old_tags: arrayRemove('legacy'),    // remove from array
  login_count: increment(1),          // atomic increment
  updated_at: serverTimestamp(),
});
```

## Security Rules

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isSignedIn() { return request.auth != null; }
    function isOwner(user_id) { return request.auth.uid == user_id; }
    function hasRole(role) {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == role;
    }
    function isValidUser() {
      return request.resource.data.keys().hasAll(['name', 'email'])
        && request.resource.data.name is string
        && request.resource.data.email.matches('.*@.*\\..*');
    }

    // Users - own data only
    match /users/{user_id} {
      allow read: if isSignedIn();
      allow create: if isOwner(user_id) && isValidUser();
      allow update: if isOwner(user_id);
      allow delete: if hasRole('admin');
    }

    // Posts - public read, authenticated write
    match /posts/{post_id} {
      allow read: if resource.data.status == 'published' || isOwner(resource.data.author_id);
      allow create: if isSignedIn() && request.resource.data.author_id == request.auth.uid;
      allow update: if isOwner(resource.data.author_id);
      allow delete: if isOwner(resource.data.author_id) || hasRole('admin');

      // Nested comments
      match /comments/{comment_id} {
        allow read: if true;
        allow create: if isSignedIn();
        allow delete: if isOwner(resource.data.author_id);
      }
    }
  }
}
```

## Firebase Auth

```typescript
import {
  getAuth, signInWithPopup, GoogleAuthProvider, signInWithEmailAndPassword,
  createUserWithEmailAndPassword, signOut, onAuthStateChanged,
  sendPasswordResetEmail, updateProfile
} from 'firebase/auth';

const auth = getAuth(app);

// Email/password
await createUserWithEmailAndPassword(auth, email, password);
await signInWithEmailAndPassword(auth, email, password);

// Social login
const provider = new GoogleAuthProvider();
provider.addScope('email');
const result = await signInWithPopup(auth, provider);
const credential = GoogleAuthProvider.credentialFromResult(result);

// Auth state observer
onAuthStateChanged(auth, (user) => {
  if (user) {
    console.log('Signed in:', user.uid, user.email);
    // Get ID token for backend verification
    user.getIdToken().then(token => setAuthHeader(token));
  } else {
    setCurrentUser(null);
  }
});

// Custom claims (set server-side via Admin SDK)
// Admin SDK: admin.auth().setCustomUserClaims(uid, { role: 'admin' })
// Client: user.getIdTokenResult() → claims.role
```

## Cloud Functions

```typescript
// functions/src/index.ts
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onCall, onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

// Firestore trigger
export const on_user_created = onDocumentCreated('users/{userId}', async (event) => {
  const user = event.data?.data();
  if (!user) return;
  await sendWelcomeEmail(user.email);
  await admin.firestore().doc(`stats/global`).update({ user_count: FieldValue.increment(1) });
});

// Callable function (with auth)
export const create_checkout = onCall({ region: 'asia-southeast1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');
  const { items } = request.data;
  // validate items...
  const session = await stripe.checkout.sessions.create({ line_items: items });
  return { session_id: session.id };
});

// HTTP endpoint
export const webhook = onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'] as string;
  const event = stripe.webhooks.constructEvent(req.rawBody, sig, process.env.STRIPE_SECRET!);
  // handle event...
  res.json({ received: true });
});

// Scheduled function
export const daily_cleanup = onSchedule('every 24 hours', async () => {
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  // delete old data...
});
```

## Offline Persistence

```typescript
import { enableIndexedDbPersistence, enableMultiTabIndexedDbPersistence } from 'firebase/firestore';

// Single tab
await enableIndexedDbPersistence(db).catch(err => {
  if (err.code === 'failed-precondition') console.warn('Multi-tab: use enableMultiTabIndexedDbPersistence');
  if (err.code === 'unimplemented') console.warn('Browser does not support persistence');
});

// Multi-tab support
await enableMultiTabIndexedDbPersistence(db);
```

## Firestore vs RTDB

| Factor | Firestore | Realtime Database |
|--------|-----------|------------------|
| Data model | Documents/Collections | JSON tree |
| Queries | Complex, indexed | Limited |
| Pricing | Per read/write/delete | Bandwidth + storage |
| Offline | Web + mobile | Mobile only |
| Scale | Auto-scales | Manual sharding |
| Best for | Most apps | Simple real-time, low latency |

## Resources

- Firestore: https://firebase.google.com/docs/firestore
- Security rules: https://firebase.google.com/docs/firestore/security/get-started
- Cloud Functions v2: https://firebase.google.com/docs/functions

## User Interaction (MANDATORY)

When activated, ask:

1. **Feature:** "Bạn cần implement gì? (queries/realtime/auth/functions/rules)"
2. **Platform:** "Web (React/Vue/Angular) hay Mobile (React Native/Flutter)?"
3. **Data structure:** "Mô tả data model bạn đang dùng"

Then provide Firebase implementation with security considerations.
