#!/usr/bin/env bash
# Publish the two layers through the GeoServer REST API (no click in the web UI).
# This is the mechanism that geoflow / geosapi drive at Geodata INRAE.
# Local only: default admin account of the official image, port bound to 127.0.0.1.
set -euo pipefail
GS=${GS:-http://127.0.0.1:8600/geoserver}
AUTH=${AUTH:-admin:geoserver}
WS=mobiliscope
CITY=${CITY:-toulouse}
rest() { curl -sS -o /dev/null -w "%{http_code} $1 $2\n" -u "$AUTH" -X "$1" "$GS/rest/$2" "${@:3}"; }

# 1. workspace
rest POST workspaces -H "Content-Type: application/json" -d "{\"workspace\":{\"name\":\"$WS\"}}"

# 2. datastore: the GeoPackage mounted read-only in the container
rest POST "workspaces/$WS/datastores" -H "Content-Type: application/json" -d "{
  \"dataStore\": {\"name\": \"$CITY\", \"connectionParameters\": {\"entry\": [
    {\"@key\": \"dbtype\",   \"\$\": \"geopkg\"},
    {\"@key\": \"database\", \"\$\": \"file:///opt/mobiliscope/$CITY.gpkg\"},
    {\"@key\": \"read_only\", \"\$\": \"true\"}]}}}"

# 3. one feature type per table, with title, abstract and keywords
publish() {  # table, title, abstract
  rest POST "workspaces/$WS/datastores/$CITY/featuretypes" -H "Content-Type: application/json" -d "{
    \"featureType\": {\"name\": \"$1\", \"nativeName\": \"$1\", \"title\": \"$2\", \"abstract\": \"$3\",
      \"srs\": \"EPSG:4326\",
      \"keywords\": {\"string\": [\"Mobiliscope\", \"mobilité quotidienne\", \"population présente\", \"$CITY\"]}}}"
}
ATTR="Source : Mobiliscope v4.3, doi:10.5281/zenodo.11111161, licence ODbL. Prototype local, non officiel."
publish "${CITY}_secteurs" "Mobiliscope - secteurs ($CITY)" "Secteurs de l'enquête de déplacements. $ATTR"
publish "${CITY}_presence" "Mobiliscope - population présente par secteur et par heure ($CITY)" \
  "Population présente estimée, un jour moyen de semaine, par secteur et par heure (nombre et densité au km2). $ATTR"
