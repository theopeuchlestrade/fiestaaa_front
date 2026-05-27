# syntax=docker/dockerfile:1.7

# Build a production web bundle and serve it with Nginx

# Pinned Flutter image for deterministic CI builds (3.41.5)
FROM ghcr.io/cirruslabs/flutter:3.41.5@sha256:5120236042c0a04d831c69fc41f0d56462d145d3b0078fdd07b50d655bbec985 AS build
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

# Keep l10n generation explicit so fresh clones and CI builds do not rely on
# tool-specific implicit generation behavior.
RUN flutter gen-l10n

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

# Use content-derived filenames for Flutter entry points so browsers do not
# keep running an old app shell after deployment.
RUN bash <<'BASH'
set -euo pipefail
asset_version="$(sha256sum build/web/main.dart.js | cut -c1-12)"
main_js="main.${asset_version}.dart.js"
bootstrap_js="flutter_bootstrap.${asset_version}.js"
cp build/web/main.dart.js "build/web/${main_js}"
sed -i "s#\"main.dart.js\"#\"${main_js}\"#g" build/web/flutter_bootstrap.js
cp build/web/flutter_bootstrap.js "build/web/${bootstrap_js}"
sed -i "s#flutter_bootstrap.js#${bootstrap_js}#g" build/web/index.html
BASH

# Pinned Nginx runtime image for deterministic production serving (1.29.2-alpine)
FROM nginx:1.29.2-alpine@sha256:61e01287e546aac28a3f56839c136b31f590273f3b41187a36f46f6a03bbfe22 AS runtime
LABEL org.opencontainers.image.source="https://github.com/theopeuchlestrade/fiestaaa_front"
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
RUN mkdir -p /var/cache/nginx /var/run /tmp \
 && chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/run /tmp
USER nginx
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
