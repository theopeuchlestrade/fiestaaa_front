# syntax=docker/dockerfile:1.7

# Build a production web bundle and serve it with Nginx

# Pinned builder base; the SDK below is upgraded from the official release.
FROM ghcr.io/cirruslabs/flutter:3.44.0@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS flutter-sdk

# Verify the official tag against its immutable revision so Docker and
# GitHub Actions use the same Flutter release.
ARG FLUTTER_VERSION=3.50.0
ARG FLUTTER_REVISION=ab2912035e160d9cad6306df307576da6128ebdb
ENV FLUTTER_VERSION=${FLUTTER_VERSION}
RUN git -C "${FLUTTER_ROOT}" fetch --depth 1 https://github.com/flutter/flutter.git "refs/tags/${FLUTTER_VERSION}:refs/tags/${FLUTTER_VERSION}" \
    && test "$(git -C "${FLUTTER_ROOT}" rev-parse FETCH_HEAD)" = "${FLUTTER_REVISION}" \
    && git -C "${FLUTTER_ROOT}" checkout --detach "${FLUTTER_REVISION}" \
    && rm -f "${FLUTTER_ROOT}/bin/cache/flutter.version.json" \
    && flutter --version --machine | grep -F "\"frameworkVersion\": \"${FLUTTER_VERSION}\"" \
    && flutter precache --web

FROM flutter-sdk AS build
WORKDIR /app

# Build-time configuration (required)
ARG FIESTAAA_API_BASE_URL
ARG FIESTAAA_APP_BASE_URL
ARG FIESTAAA_GOOGLE_WEB_CLIENT_ID
ARG FIESTAAA_APPLE_SERVICE_ID
ARG FIESTAAA_APPLE_REDIRECT_URI
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_STORAGE_BUCKET
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_WEB_APP_ID
# Public store signing identifiers; mandatory for an associated beta web build.
ARG IOS_TEAM_ID=""
ARG ANDROID_APP_SIGNING_SHA256=""
ARG FIESTAAA_REQUIRE_APP_ASSOCIATIONS="false"
ARG FIESTAAA_APP_ASSOCIATION_PLATFORMS="all"
# Optional
ARG FIREBASE_WEB_MEASUREMENT_ID=""
ARG FIESTAAA_SENTRY_DSN=""
ARG FIESTAAA_SENTRY_ENVIRONMENT="production"
ARG FIESTAAA_SENTRY_RELEASE=""
ARG FIESTAAA_SENTRY_TRACES_SAMPLE_RATE="0"

# Cache pub deps
COPY pubspec.* ./
RUN flutter pub get --enforce-lockfile

# Source code
COPY . .

RUN if [ "$FIESTAAA_REQUIRE_APP_ASSOCIATIONS" = "true" ] || [ -n "$IOS_TEAM_ID$ANDROID_APP_SIGNING_SHA256" ]; then \
      IOS_TEAM_ID="$IOS_TEAM_ID" ANDROID_APP_SIGNING_SHA256="$ANDROID_APP_SIGNING_SHA256" FIESTAAA_APP_ASSOCIATION_PLATFORMS="$FIESTAAA_APP_ASSOCIATION_PLATFORMS" dart run tool/generate_app_associations.dart; \
    fi

# Keep the web server policy aligned with the public origins compiled into the
# application. The generated file contains public origins only.
RUN dart run tool/generate_nginx_config.dart \
  --production \
  "--api-base-url=${FIESTAAA_API_BASE_URL}" \
  --template=nginx.conf \
  --output=build/nginx.conf

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

flutter build web --release --web-content-hash --no-deprecated-js-interop \
  "--dart-define=FIESTAAA_API_BASE_URL=${FIESTAAA_API_BASE_URL}" \
  "--dart-define=FIESTAAA_APP_BASE_URL=${FIESTAAA_APP_BASE_URL}" \
  "--dart-define=FIESTAAA_GOOGLE_WEB_CLIENT_ID=${FIESTAAA_GOOGLE_WEB_CLIENT_ID}" \
  "--dart-define=FIESTAAA_APPLE_SERVICE_ID=${FIESTAAA_APPLE_SERVICE_ID}" \
  "--dart-define=FIESTAAA_APPLE_REDIRECT_URI=${FIESTAAA_APPLE_REDIRECT_URI}" \
  "--dart-define=FIESTAAA_FCM_VAPID_KEY=${fcm_vapid_key}" \
  "--dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}" \
  "--dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET}" \
  "--dart-define=FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}" \
  "--dart-define=FIREBASE_WEB_API_KEY=${firebase_web_api_key}" \
  "--dart-define=FIREBASE_WEB_APP_ID=${FIREBASE_WEB_APP_ID}" \
  "--dart-define=FIREBASE_WEB_MEASUREMENT_ID=${FIREBASE_WEB_MEASUREMENT_ID}" \
  "--dart-define=FIESTAAA_SENTRY_DSN=${FIESTAAA_SENTRY_DSN}" \
  "--dart-define=FIESTAAA_SENTRY_ENVIRONMENT=${FIESTAAA_SENTRY_ENVIRONMENT}" \
  "--dart-define=FIESTAAA_SENTRY_RELEASE=${FIESTAAA_SENTRY_RELEASE}" \
  "--dart-define=FIESTAAA_SENTRY_TRACES_SAMPLE_RATE=${FIESTAAA_SENTRY_TRACES_SAMPLE_RATE}"

# This plugin registers its worker by a fixed URL outside Flutter's asset loader.
worker_dir=build/web/assets/packages/flutter_local_notifications_web/web
cp "${worker_dir}"/notifications_service_worker.*.js "${worker_dir}/notifications_service_worker.js"
BASH

# Pinned Nginx stable runtime image for production serving (1.30.6-alpine)
FROM nginx:1.30.6-alpine@sha256:0e52bd054126cdc040b1276c0af347aeb02a41b9cfe305d6094767ac30e97949 AS runtime
# This immutable base already includes libexpat 2.9.0-r0 and pcre2 10.49-r0.
# Keep those fixes in the pinned image rather than requesting obsolete APKs.
# Patch the remaining fixable HIGH findings without relaxing the scan gate.
RUN apk add --no-cache brotli-libs=1.2.1-r0 curl=8.23.0-r0 libcurl=8.23.0-r0
LABEL org.opencontainers.image.source="https://github.com/theopeuchlestrade/fiestaaa_front"
COPY --from=build /app/build/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
# Static public pages also use Manrope outside Flutter's asset manifest.
COPY --from=build /app/assets/fonts/Manrope.ttf /usr/share/nginx/html/assets/assets/fonts/Manrope.ttf
RUN sed -i \
      -e 's#pid[[:space:]]\+/run/nginx.pid;#pid /tmp/nginx.pid;#' \
      -e 's#pid[[:space:]]\+/var/run/nginx.pid;#pid /tmp/nginx.pid;#' \
      /etc/nginx/nginx.conf \
 && mkdir -p /var/cache/nginx /var/run /tmp \
 && chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/run /tmp
USER nginx
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
