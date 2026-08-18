// Firebase bootstrap for the MFU Security module (live tracking, SOS, incidents, tasks, schedule, logs).
//
// IMPORTANT: these collection names and field names are SHARED with the Flutter guard +
// admin apps — this web dashboard reads and writes the exact same Firestore documents a
// guard's phone does (check-in location, SOS alerts, incident reports, assigned
// tasks/shifts, and the notifications a guard's Alerts screen shows). Don't rename these
// without also updating the Flutter side (guard_location_service.dart) to match.
//
// Config values come from environment variables so keys are never hard-coded in the repo.
// Add them to your .env / .env.<mode> files, e.g.:
//   VUE_APP_FIREBASE_API_KEY=xxx
//   VUE_APP_FIREBASE_AUTH_DOMAIN=xxx.firebaseapp.com
//   VUE_APP_FIREBASE_PROJECT_ID=xxx
//   VUE_APP_FIREBASE_STORAGE_BUCKET=xxx.appspot.com
//   VUE_APP_FIREBASE_MESSAGING_SENDER_ID=xxx
//   VUE_APP_FIREBASE_APP_ID=xxx

import { initializeApp, getApps } from 'firebase/app'
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
  apiKey: process.env.VUE_APP_FIREBASE_API_KEY,
  authDomain: process.env.VUE_APP_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.VUE_APP_FIREBASE_PROJECT_ID,
  storageBucket: process.env.VUE_APP_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.VUE_APP_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.VUE_APP_FIREBASE_APP_ID
}

const firebaseApp = getApps().length ? getApps()[0] : initializeApp(firebaseConfig)
const db = getFirestore(firebaseApp)

// These ARE the real collections the Flutter guard/admin apps read and write —
// previously this pointed at a separate `mfuSecurity*` namespace that never saw any
// data from the mobile apps at all.
export const COLLECTIONS = {
  GUARDS: 'locations', // live location + working/outOfScope status, written by the guard app every few seconds while on shift
  USERS: 'users', // guard profile (name, phone, photoUrl) — doc id IS the Firebase Auth uid
  SOS: 'sos', // emergency alerts sent from the guard app's SOS screen
  INCIDENTS: 'incidents',
  TASKS: 'tasks',
  SCHEDULES: 'schedules',
  NOTIFICATIONS: 'notifications' // what the guard app's Alerts screen reads
}

// `sos` documents use a field called `timestamp` (not `createdAt`) — that's what the
// Flutter guard app's GuardLocationService.sendSOS() writes. Every other collection here
// (schedules/tasks/incidents) uses `createdAt`, which is also what addDocument() below
// auto-stamps on every write, so only SOS-derived reads need this override.
export const SOS_ORDER_FIELD = 'timestamp'

/**
 * Subscribe to a collection in realtime.
 * @param {string} name - one of COLLECTIONS
 * @param {(rows: Array<object>) => void} callback
 * @param {{ orderByField?: string, direction?: 'asc'|'desc' }} [options]
 * @returns {() => void} unsubscribe function
 */
export function subscribeCollection (name, callback, options = {}) {
  const colRef = collection(db, name)
  const q = options.orderByField
    ? query(colRef, orderBy(options.orderByField, options.direction || 'desc'))
    : colRef
  return onSnapshot(q, snapshot => {
    const rows = snapshot.docs.map(docSnap => Object.assign({ id: docSnap.id }, docSnap.data()))
    callback(rows)
  }, error => {
    // eslint-disable-next-line no-console
    console.error('[firebase] subscribeCollection error for ' + name, error)
  })
}

export function addDocument (name, payload) {
  return addDoc(collection(db, name), Object.assign({}, payload, { createdAt: serverTimestamp() }))
}

export function updateDocument (name, id, payload) {
  return updateDoc(doc(db, name, id), Object.assign({}, payload, { updatedAt: serverTimestamp() }))
}

export function deleteDocument (name, id) {
  return deleteDoc(doc(db, name, id))
}

/**
 * Treats a guard as "online" exactly the way the Flutter admin app does: their
 * `locations/{uid}` doc must have been updated within the last 60 seconds, or they're
 * considered off-shift even if `working` is still `true` in Firestore (e.g. the guard's
 * phone died or lost network without a clean check-out).
 */
export function isGuardOnline (guard) {
  if (!guard || !guard.lastUpdate || typeof guard.lastUpdate.toDate !== 'function') return false
  const diffMs = Date.now() - guard.lastUpdate.toDate().getTime()
  return diffMs <= 60 * 1000
}

/**
 * Writes a notification the guard's own Alerts screen will show — the same
 * `notifications` collection the Flutter admin app writes to when accepting an SOS or
 * assigning a task/shift (see GuardActions.acceptSos). Keeps both admin surfaces in sync
 * so it doesn't matter whether an action was taken from this web dashboard or the
 * Flutter admin app.
 */
export function notifyGuard (targetUid, { title, subtitle, category = 'notice', relatedId } = {}) {
  if (!targetUid) return Promise.resolve()
  return addDoc(collection(db, COLLECTIONS.NOTIFICATIONS), {
    targetUid,
    title,
    subtitle,
    category,
    relatedId: relatedId || null,
    timestamp: serverTimestamp()
  })
}

export { db, serverTimestamp }
export default db
