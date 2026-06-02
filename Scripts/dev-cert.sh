#!/usr/bin/env bash
# Create a self-signed "ActionRing Dev" code-signing identity in your login
# keychain. bundle.sh will then sign with it, giving ActionRing a STABLE code
# identity — so the Accessibility permission you grant survives every rebuild
# (ad-hoc signing changes the hash each build and loses the grant).
#
# One-time. Reversible: delete the "ActionRing Dev" cert in Keychain Access.
# May prompt for your login-keychain password.
set -euo pipefail

NAME="ActionRing Dev"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$NAME"; then
    echo "✅ '$NAME' code-signing identity already exists. Run: make bundle"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cfg" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $NAME
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

echo "▶ Generating self-signed code-signing certificate…"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cfg" >/dev/null 2>&1
# `-legacy` produces a PKCS12 MAC that Apple's `security import` accepts
# (OpenSSL 3's default SHA-256 MAC fails with "MAC verification failed").
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -passout pass:actionring -name "$NAME" >/dev/null 2>&1

KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
echo "▶ Importing into login keychain…"
security import "$TMP/id.p12" -k "$KEYCHAIN" -P actionring -T /usr/bin/codesign -A >/dev/null 2>&1

echo "▶ Trusting it for code signing (may prompt for your keychain password)…"
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" >/dev/null 2>&1 \
    || echo "  (trust step skipped — if 'make bundle' can't use it, trust 'ActionRing Dev' for Code Signing in Keychain Access)"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$NAME"; then
    echo "✅ Done. Now run:  make bundle  (the grant will persist across rebuilds)"
else
    echo "⚠️  Identity created but not yet listed as valid for code signing."
    echo "   Open Keychain Access → 'ActionRing Dev' → Get Info → Trust → Code Signing: Always Trust."
fi
