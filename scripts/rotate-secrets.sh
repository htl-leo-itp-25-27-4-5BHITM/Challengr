#!/usr/bin/env zsh
# Neue starke Passwörter für die Leo Cloud (Checkliste A6) – einmalig selbst ausführen.
#
#  1. erzeugt zufällige Passwörter für Postgres, den Keycloak-Admin und den Apple-Prüfer-Account
#  2. speichert sie im macOS-Schlüsselbund ("Challengr Leo Cloud …")
#  3. setzt sie in Postgres und Keycloak, dann im Kubernetes-Secret challengr-secrets
#  4. startet Keycloak und Backend neu und wartet, bis beide laufen
#
# Vorher: Backup ziehen (siehe docs/audit/TESTFLIGHT_ANLEITUNG.md). Die Passwörter werden nie ausgegeben.
# Wieder anzeigen: security find-generic-password -s "Challengr Leo Cloud Postgres" -w
set -euo pipefail

NS="${K8S_NAMESPACE:-student-it220257}"
CURRENT_KC_ADMIN_PASSWORD="${CURRENT_KC_ADMIN_PASSWORD:-admin}"

k() { kubectl -n "$NS" "$@"; }
kc() { k exec deploy/challengr-keycloak -- /opt/keycloak/bin/kcadm.sh "$@" --config /tmp/kcadm-rotate.config; }
newpw() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; }

PG_PW=$(newpw)
KC_PW=$(newpw)
REVIEW_PW=$(newpw | head -c 16)

echo "→ Passwörter im Schlüsselbund speichern"
security add-generic-password -U -a postgres  -s "Challengr Leo Cloud Postgres"       -w "$PG_PW"
security add-generic-password -U -a admin     -s "Challengr Leo Cloud Keycloak-Admin" -w "$KC_PW"
security add-generic-password -U -a applereview -s "Challengr Apple-Prüfer-Account"   -w "$REVIEW_PW"

echo "→ Keycloak: anmelden"
kc config credentials --server http://localhost:8080/auth --realm master --user admin --password "$CURRENT_KC_ADMIN_PASSWORD" >/dev/null

echo "→ Keycloak: Prüfer-Account 'applereview' (für die TestFlight-Beta-Prüfung)"
if ! kc get users -r challengr -q username=applereview --fields id | grep -q '"id"'; then
  kc create users -r challengr -s username=applereview -s enabled=true -s emailVerified=true \
     -s email=challengrapp.official+review@gmail.com -s firstName=Apple -s lastName=Review >/dev/null
fi
kc set-password -r challengr --username applereview --new-password "$REVIEW_PW"

echo "→ Keycloak: neues Admin-Passwort"
kc set-password -r master --username admin --new-password "$KC_PW"

echo "→ Postgres: neues Passwort"
echo "ALTER USER postgres PASSWORD '$PG_PW';" | k exec -i deploy/challengr-postgres -- psql -U postgres -q -v ON_ERROR_STOP=1

echo "→ Secret challengr-secrets aktualisieren"
k patch secret challengr-secrets --type merge \
  -p "{\"stringData\":{\"POSTGRES_PASSWORD\":\"$PG_PW\",\"KEYCLOAK_ADMIN_PASSWORD\":\"$KC_PW\"}}" >/dev/null

echo "→ Keycloak und Backend neu starten (nutzen beide das Postgres-Passwort)"
k rollout restart deployment/challengr-keycloak deployment/challengr-backend
k rollout status deployment/challengr-keycloak --timeout=300s
k rollout status deployment/challengr-backend --timeout=300s

echo "✅ Fertig. Passwörter stehen im Schlüsselbund unter \"Challengr Leo Cloud …\" bzw. \"Challengr Apple-Prüfer-Account\"."
