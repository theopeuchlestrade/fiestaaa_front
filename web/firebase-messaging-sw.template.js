// Firebase Messaging service worker template.
// Values are filled from your .env file via tool/generate_firebase_sw.dart.

self.FIREBASE_PROJECT_ID = "{{FIREBASE_PROJECT_ID}}";
self.FIREBASE_STORAGE_BUCKET = "{{FIREBASE_STORAGE_BUCKET}}";
self.FIREBASE_MESSAGING_SENDER_ID = "{{FIREBASE_MESSAGING_SENDER_ID}}";
self.FIREBASE_WEB_API_KEY = "{{FIREBASE_WEB_API_KEY}}";
self.FIREBASE_WEB_APP_ID = "{{FIREBASE_WEB_APP_ID}}";
self.FIREBASE_WEB_MEASUREMENT_ID = "{{FIREBASE_WEB_MEASUREMENT_ID}}";
self.FIREBASE_AUTH_DOMAIN = "{{FIREBASE_AUTH_DOMAIN}}";

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: self.FIREBASE_WEB_API_KEY || "",
  authDomain:
    self.FIREBASE_AUTH_DOMAIN ||
    (self.FIREBASE_PROJECT_ID
      ? `${self.FIREBASE_PROJECT_ID}.firebaseapp.com`
      : ""),
  projectId: self.FIREBASE_PROJECT_ID || "",
  storageBucket: self.FIREBASE_STORAGE_BUCKET || "",
  messagingSenderId: self.FIREBASE_MESSAGING_SENDER_ID || "",
  appId: self.FIREBASE_WEB_APP_ID || "",
  measurementId: self.FIREBASE_WEB_MEASUREMENT_ID || ""
};

const hasConfig = Boolean(
  firebaseConfig.apiKey &&
    firebaseConfig.projectId &&
    firebaseConfig.messagingSenderId &&
    firebaseConfig.appId
);

if (!hasConfig) {
  console.error(
    "Firebase config manquant pour le service worker (FIREBASE_* non fournis)"
  );
} else {
  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    const notificationTitle = payload.notification?.title || "Notification";
    const notificationOptions = {
      body: payload.notification?.body,
      data: payload.data,
    };
    self.registration.showNotification(
      notificationTitle,
      notificationOptions
    );
  });
}
