importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: "AIzaSyAmBCgPGSvoD2T43NdXo9ktSo4HYYm2zSs",
  authDomain: "fiestaaa-app.firebaseapp.com",
  projectId: "fiestaaa-app",
  storageBucket: "fiestaaa-app.firebasestorage.app",
  messagingSenderId: "900475997784",
  appId: "1:900475997784:web:c84668179aa61dbac6042d",
  measurementId: "G-0TGSYBMDZ6"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || "Notification";
  const notificationOptions = {
    body: payload.notification?.body,
    data: payload.data,
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
