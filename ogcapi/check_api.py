#!/usr/bin/env python3
"""Compare what the API answers with the source files of the open data.

Usage: check_api.py <OGC API base URL> <city> <open data folder>
Standard library only. Exits with 1 if a check fails.
"""
import csv
import json
import sys
import urllib.parse
import urllib.request

base, city, data_dir = sys.argv[1:4]
ok = True


def get(path, **params):
    params.setdefault("f", "application/geo+json")
    url = f"{base}{path}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url) as r:
        return json.load(r)


def check(label, got, expected):
    global ok
    same = got == expected
    ok &= same
    print(f"{'OK  ' if same else 'FAIL'} {label}: API {got} | source {expected}")


# 1. as many sectors as in the source layer
src = json.load(open(f"{data_dir}/{city}/geo/pop0_prop.geojson", encoding="utf-8"))
api = get(f"/collections/{city}_secteurs/items", limit=1000)
check("number of sectors", len(api["features"]), len(src["features"]))

# 2. one hour, filtered on the server (CQL2 text): one feature per sector
api14 = get(f"/collections/{city}_presence/items", limit=1000, filter="hour=14")
check("features at 14:00", len(api14["features"]), len(src["features"]))

# 3. every value at 14:00 equals the published CSV ("2pm" column of the stacked file)
with open(f"{data_dir}/{city}/stacked/pop_prop_stacked.csv", encoding="utf-8") as fh:
    csv14 = {r["district"]: float(r["pop0"]) for r in csv.DictReader(fh) if r["hour"] == "2pm"}
api_vals = {f["properties"]["secteur"]: f["properties"]["pop_presente"] for f in api14["features"]}
diff = max(abs(api_vals[k] - v) for k, v in csv14.items())
check("largest difference with the CSV at 14:00", round(diff, 6), 0.0)
check("total population present at 14:00", round(sum(api_vals.values())), round(sum(csv14.values())))

sys.exit(0 if ok else 1)
