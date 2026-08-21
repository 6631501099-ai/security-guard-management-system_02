// Firebase bootstrap for the MFU Security module (live tracking, SOS, incidents, tasks, schedule, logs).
//
// IMPORTANT: these collection names and field names are SHARED with the Flutter guard +
// admin apps — this web dashboard reads and writes the exact same Firestore documents a
// guard's phone does (check-in location, SOS alerts, incident reports, assigned
// tasks/shifts, and the notifications a guard's Alerts screen shows). Don't rename these
// without also updating the Flutter side (guard_location_service.dart) to match.

import { initializeApp, getApps } from 'firebase/app'
import {
  getAuth,
  signInAnonymously,
  signInWithEmailAndPassword,
  onAuthStateChanged
} from 'firebase/auth'
import {
  getFirestore,
  collection,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  onSnapshot,
  query,
  orderBy,
  serverTimestamp
} from 'firebase/firestore'

const firebaseConfig = {
  apiKey: process.env.VUE_APP_FIREBASE_API_KEY || 'AIzaSyCJCeOSI7_K6yasAhWXQ2ZKMz5Jq2H5WtM',
  authDomain: process.env.VUE_APP_FIREBASE_AUTH_DOMAIN || 'location-app-project-ce854.firebaseapp.com',
  databaseURL: process.env.VUE_APP_FIREBASE_DATABASE_URL || 'https://location-app-project-ce854-default-rtdb.asia-southeast1.firebasedatabase.app',
  projectId: process.env.VUE_APP_FIREBASE_PROJECT_ID || 'location-app-project-ce854',
  storageBucket: process.env.VUE_APP_FIREBASE_STORAGE_BUCKET || 'location-app-project-ce854.firebasestorage.app',
  messagingSenderId: process.env.VUE_APP_FIREBASE_MESSAGING_SENDER_ID || '755991867844',
  appId: process.env.VUE_APP_FIREBASE_APP_ID || '1:755991867844:web:24089d90989379b7b63491'
}

const firebaseApp = getApps().length ? getApps()[0] : initializeApp(firebaseConfig)
const db = getFirestore(firebaseApp)
const auth = getAuth(firebaseApp)

let authPromise = null

export function loginFirebase (email, password) {
  return signInWithEmailAndPassword(auth, email, password).then(cred => {
    try {
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem('mfu_firebase_email', email)
        localStorage.setItem('mfu_firebase_pass', password)
      }
    } catch (e) {
      // ignore storage error
    }
    return cred.user
  })
}

/**
 * Ensures Firebase Auth is authenticated before reading/writing Firestore,
 * satisfying Firestore Security Rules requirement (request.auth != null).
 */
export function ensureAuth () {
  if (auth.currentUser) return Promise.resolve(auth.currentUser)
  if (authPromise) return authPromise

  authPromise = new Promise((resolve) => {
    try {
      const unsub = onAuthStateChanged(auth, user => {
        if (user) {
          if (typeof unsub === 'function') unsub()
          resolve(user)
        }
      })

      let storedEmail = ''
      let storedPass = ''
      try {
        if (typeof localStorage !== 'undefined') {
          storedEmail = localStorage.getItem('mfu_firebase_email') || ''
          storedPass = localStorage.getItem('mfu_firebase_pass') || ''
        }
      } catch (e) {
        // ignore storage error
      }

      const adminEmail = storedEmail || process.env.VUE_APP_FIREBASE_ADMIN_EMAIL
      const adminPass = storedPass || process.env.VUE_APP_FIREBASE_ADMIN_PASSWORD

      const doAnon = () => {
        signInAnonymously(auth)
          .then(cred => resolve(cred.user))
          .catch(err => {
            // eslint-disable-next-line no-console
            console.warn('[firebase] signInAnonymously failed', err)
            resolve(null)
          })
      }

      if (adminEmail && adminPass) {
        signInWithEmailAndPassword(auth, adminEmail, adminPass)
          .then(cred => resolve(cred.user))
          .catch(err => {
            // eslint-disable-next-line no-console
            console.warn('[firebase] stored login failed, trying anonymous auth...', err)
            doAnon()
          })
      } else {
        doAnon()
      }
    } catch (e) {
      resolve(null)
    }
  })

  return authPromise
}

// Collections
export const COLLECTIONS = {
  GUARDS: 'locations',
  USERS: 'users',
  SOS: 'sos',
  INCIDENTS: 'incidents',
  TASKS: 'tasks',
  SCHEDULES: 'schedules',
  NOTIFICATIONS: 'notifications'
}

export const SOS_ORDER_FIELD = 'timestamp'

/**
 * Subscribe to a collection in realtime.
 * @param {string} name - one of COLLECTIONS
 * @param {(rows: Array<object>) => void} callback
 * @param {{ orderByField?: string, direction?: 'asc'|'desc', onError?: (err: Error) => void }} [options]
 * @returns {() => void} unsubscribe function
 */
export function subscribeCollection (name, callback, options = {}) {
  let unsub = null
  let isCancelled = false

  const onError = (error) => {
    // eslint-disable-next-line no-console
    console.error('[firebase] subscribeCollection error for ' + name, error)
    if (typeof options.onError === 'function') {
      options.onError(error)
    }
  }

  const startListen = () => {
    if (isCancelled) return
    try {
      const colRef = collection(db, name)
      const q = options.orderByField
        ? query(colRef, orderBy(options.orderByField, options.direction || 'desc'))
        : colRef

      unsub = onSnapshot(q, snapshot => {
        if (isCancelled) return
        const rows = snapshot.docs.map(docSnap => Object.assign({ id: docSnap.id }, docSnap.data()))
        callback(rows)
      }, error => {
        if (options.orderByField) {
          // eslint-disable-next-line no-console
          console.warn(`[firebase] query with orderBy(${options.orderByField}) failed, falling back to unordered query`, error)
          try {
            unsub = onSnapshot(colRef, snapshot => {
              if (isCancelled) return
              const rows = snapshot.docs.map(docSnap => Object.assign({ id: docSnap.id }, docSnap.data()))
              callback(rows)
            }, onError)
          } catch (e) {
            onError(e)
          }
        } else {
          onError(error)
        }
      })
    } catch (err) {
      onError(err)
    }
  }

  ensureAuth().then(() => {
    if (!isCancelled && !unsub) {
      startListen()
    }
  }).catch(() => {})

  startListen()

  return () => {
    isCancelled = true
    if (typeof unsub === 'function') unsub()
  }
}

export async function addDocument (name, payload) {
  await ensureAuth().catch(() => {})
  return addDoc(collection(db, name), Object.assign({}, payload, { createdAt: serverTimestamp() }))
}

export async function updateDocument (name, id, payload) {
  await ensureAuth().catch(() => {})
  return updateDoc(doc(db, name, id), Object.assign({}, payload, { updatedAt: serverTimestamp() }))
}

export async function deleteDocument (name, id) {
  await ensureAuth().catch(() => {})
  return deleteDoc(doc(db, name, id))
}

export async function notifyGuard (targetUid, { title, subtitle, category = 'notice', relatedId } = {}) {
  if (!targetUid) return Promise.resolve()
  await ensureAuth().catch(() => {})
  return addDoc(collection(db, COLLECTIONS.NOTIFICATIONS), {
    targetUid,
    title,
    subtitle,
    category,
    relatedId: relatedId || null,
    timestamp: serverTimestamp()
  })
}

/**
 * Treats a guard as "online" exactly the way the Flutter admin app does.
 */
export function isGuardOnline (guard) {
  if (!guard || !guard.lastUpdate || typeof guard.lastUpdate.toDate !== 'function') return false
  const diffMs = Date.now() - guard.lastUpdate.toDate().getTime()
  return diffMs <= 60 * 1000
}

export { db, auth, serverTimestamp }
export default db
