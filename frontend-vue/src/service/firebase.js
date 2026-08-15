// Firebase bootstrap for the MFU Security module (live tracking, SOS, incidents, tasks, schedule, logs).
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

// Collection names used by the MFU Security module (kept in one place so they never drift).
export const COLLECTIONS = {
  GUARDS: 'mfuSecurityGuards',
  SOS: 'mfuSecuritySos',
  INCIDENTS: 'mfuSecurityIncidents',
  TASKS: 'mfuSecurityTasks',
  SCHEDULES: 'mfuSecuritySchedules',
  LOGS: 'mfuSecurityLogs'
}

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

export { db, serverTimestamp }
export default db
