# Build a production web bundle and serve it with Nginx

# Note: certaines tags GHCR ne sont pas disponibles; on utilise l'image Docker Hub cirrusci/flutter stable 3.24.0
FROM cirrusci/flutter:3.24.0 AS build
WORKDIR /app

# Build-time configuration (required)
ARG FIESTAAA_API_BASE_URL
ARG FIESTAAA_GOOGLE_WEB_CLIENT_ID
ARG FIESTAAA_APPLE_SERVICE_ID
ARG FIESTAAA_APPLE_REDIRECT_URI
ARG FIESTAAA_FCM_VAPID_KEY
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_STORAGE_BUCKET
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_WEB_API_KEY
ARG FIREBASE_WEB_APP_ID
# Optional
ARG FIREBASE_WEB_MEASUREMENT_ID=""
ARG FIREBASE_AUTH_DOMAIN=""

# Cache pub deps
COPY pubspec.* ./
RUN flutter pub get --enforce-lockfile

# Source code
COPY . .

# Generate the Firebase service worker from build-time env
RUN set -euo pipefail; \
  auth_domain="${FIREBASE_AUTH_DOMAIN:-${FIREBASE_PROJECT_ID}.firebaseapp.com}"; \
  cat > .env <<EOF
FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}
FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET}
FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}
FIREBASE_WEB_API_KEY=${FIREBASE_WEB_API_KEY}
FIREBASE_WEB_APP_ID=${FIREBASE_WEB_APP_ID}
FIREBASE_WEB_MEASUREMENT_ID=${FIREBASE_WEB_MEASUREMENT_ID}
FIREBASE_AUTH_DOMAIN=${auth_domain}
EOF
RUN dart run tool/generate_firebase_sw.dart

# Build Flutter web bundle with the required dart-defines
RUN flutter build web --release \
  --dart-define=FIESTAAA_API_BASE_URL=${FIESTAAA_API_BASE_URL} \
  --dart-define=FIESTAAA_GOOGLE_WEB_CLIENT_ID=${FIESTAAA_GOOGLE_WEB_CLIENT_ID} \
  --dart-define=FIESTAAA_APPLE_SERVICE_ID=${FIESTAAA_APPLE_SERVICE_ID} \
  --dart-define=FIESTAAA_APPLE_REDIRECT_URI=${FIESTAAA_APPLE_REDIRECT_URI} \
  --dart-define=FIESTAAA_FCM_VAPID_KEY=${FIESTAAA_FCM_VAPID_KEY} \
  --dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
  --dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET} \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID} \
  --dart-define=FIREBASE_WEB_API_KEY=${FIREBASE_WEB_API_KEY} \
  --dart-define=FIREBASE_WEB_APP_ID=${FIREBASE_WEB_APP_ID} \
  --dart-define=FIREBASE_WEB_MEASUREMENT_ID=${FIREBASE_WEB_MEASUREMENT_ID}

FROM nginx:alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
