# Google authentication deployment

KAN-48 verifies Google RS256 ID tokens using Google's fixed JWKS URL. Configure `GOOGLE_CLIENT_IDS` as a comma-separated allowlist of OAuth client IDs. Client IDs are public configuration; a web client secret is not needed for this ID-token flow. Do not put tokens or client secrets in Git or logs.

Deploy API and web together: set `DEV_AUTH_ENABLED=false`; include `https://orcex.shop` in `CORS_ORIGIN`; compile web without `ENABLE_DEMO=true`. The production web origin must exactly match the authorized JavaScript origin in Google Cloud. Test development origins must be registered separately before using Google there.

New accounts are buyers with seller approval false. A Google login never grants seller/admin. Existing accounts are linked only by Google subject; an email collision fails closed and requires deliberate operator review, not automatic account linking. Existing demo records are preserved.

The frontend keeps the ID token only in memory. Reloading requires signing in again. Before token expiry it returns to the access screen; the API independently rejects expired tokens. No long-lived refresh session is claimed by this implementation. Android remains a later task.

Verification: RSA-signed synthetic tokens cover valid identity, wrong signature, issuer, audience, expiry, future issuance, unverified email, empty subject, unauthorized presenter, and malformed credentials. Confirm an actual Google login in the browser after deployment; automated tests do not establish real account approval or provider availability.
