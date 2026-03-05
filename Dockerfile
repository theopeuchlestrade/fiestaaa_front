# syntax=docker/dockerfile:1.7

# Build a production web bundle and serve it with Nginx

# Pinned Flutter image for deterministic CI builds (3.41.2)
FROM ghcr.io/cirruslabs/flutter:3.41.2@sha256:c690397aed33cf1a05ef9fee2871346bbe93fc09d3e437e15c5e49395f806127 AS build
WORKDIR /app

# Build-time configuration (required)
ARG FIESTAAA_API_BASE_URL
ARG FIESTAAA_GOOGLE_WEB_CLIENT_ID
ARG FIESTAAA_APPLE_SERVICE_ID
ARG FIESTAAA_APPLE_REDIRECT_URI
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_STORAGE_BUCKET
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_WEB_APP_ID
# Optional
ARG FIREBASE_WEB_MEASUREMENT_ID=""

# Cache pub deps
COPY pubspec.* ./
RUN flutter pub get --enforce-lockfile

# Source code
COPY . .

# Generate the Firebase service worker from build-time env
RUN --mount=type=secret,id=FIREBASE_WEB_API_KEY \
    --mount=type=secret,id=FIREBASE_AUTH_DOMAIN,required=false \
    bash <<'BASH'
set -euo pipefail
firebase_web_api_key="$(tr -d '\r\n' </run/secrets/FIREBASE_WEB_API_KEY)"
auth_domain_file="/run/secrets/FIREBASE_AUTH_DOMAIN"
if [ -s "${auth_domain_file}" ]; then
  auth_domain="$(tr -d '\r\n' <"${auth_domain_file}")"
else
  auth_domain="${FIREBASE_PROJECT_ID}.firebaseapp.com"
fi

cat > .env <<EOF
FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}
FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET}
FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}
FIREBASE_WEB_API_KEY=${firebase_web_api_key}
FIREBASE_WEB_APP_ID=${FIREBASE_WEB_APP_ID}
FIREBASE_WEB_MEASUREMENT_ID=${FIREBASE_WEB_MEASUREMENT_ID}
FIREBASE_AUTH_DOMAIN=${auth_domain}
EOF
dart run tool/generate_firebase_sw.dart
rm -f .env
BASH

# Build Flutter web bundle with the required dart-defines
RUN --mount=type=secret,id=FIESTAAA_FCM_VAPID_KEY \
    --mount=type=secret,id=FIREBASE_WEB_API_KEY \
    bash <<'BASH'
set -euo pipefail
fcm_vapid_key="$(tr -d '\r\n' </run/secrets/FIESTAAA_FCM_VAPID_KEY)"
firebase_web_api_key="$(tr -d '\r\n' </run/secrets/FIREBASE_WEB_API_KEY)"

flutter build web --release \
  "--dart-define=FIESTAAA_API_BASE_URL=${FIESTAAA_API_BASE_URL}" \
  "--dart-define=FIESTAAA_GOOGLE_WEB_CLIENT_ID=${FIESTAAA_GOOGLE_WEB_CLIENT_ID}" \
  "--dart-define=FIESTAAA_APPLE_SERVICE_ID=${FIESTAAA_APPLE_SERVICE_ID}" \
  "--dart-define=FIESTAAA_APPLE_REDIRECT_URI=${FIESTAAA_APPLE_REDIRECT_URI}" \
  "--dart-define=FIESTAAA_FCM_VAPID_KEY=${fcm_vapid_key}" \
  "--dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}" \
  "--dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET}" \
  "--dart-define=FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}" \
  "--dart-define=FIREBASE_WEB_API_KEY=${firebase_web_api_key}" \
  "--dart-define=FIREBASE_WEB_APP_ID=${FIREBASE_WEB_APP_ID}" \
  "--dart-define=FIREBASE_WEB_MEASUREMENT_ID=${FIREBASE_WEB_MEASUREMENT_ID}"
BASH

FROM nginx:alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
