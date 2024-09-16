import { initializeApp, applicationDefault } from "firebase-admin/app";

export function initFirebaseAdmin() {
  initializeApp({
    credential: applicationDefault(),
  });
}