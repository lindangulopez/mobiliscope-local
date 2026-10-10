#!/usr/bin/env python3
"""Build the layers the local OGC API serves, from the Mobiliscope open data.

Input  : one city folder of the Zenodo open data v4.3 (ODbL, doi:10.5281/zenodo.11111161)
Output : data/<city>_secteurs.geojson   one feature per sector
         data/<city>_presence.geojson   one feature per sector and hour (long form)

The open data store one column per hour (pop0_h4 ... pop0_h27, where h24-h27
are 0 am to 3 am of the next day). An API is easier to query in long form:
one row per sector and hour, so that `hour = 14` is a simple filter.

Standard library only. Usage: prepare_data.py <city folder> <out folder>
"""
import json
import sys
from pathlib import Path

city_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
city = city_dir.name
KEEP = ["CITYKEY", "ENQUETE", "ANNEE", "Secteur_EM", "LIB", "AREA"]


def load(name):
    return json.loads((city_dir / "geo" / name).read_text(encoding="utf-8"))


# pop0_prop: number of people present; pop0_choro: the same per km2
number = load("pop0_prop.geojson")
density = {f["properties"]["Secteur_EM"]: f["properties"]
           for f in load("pop0_choro.geojson")["features"]}
polygons = {f["properties"]["Secteur_EM"]: f["geometry"] for f in number["features"]}

sectors, presence = [], []
for f in number["features"]:
    p = f["properties"]
    code = p["Secteur_EM"]
    base = {k.lower(): p[k] for k in KEEP if k in p}
    base["secteur"] = base.pop("secteur_em")
    sectors.append({"type": "Feature", "geometry": polygons[code], "properties": base})
    for h in range(4, 28):
        presence.append({
            "type": "Feature",
            "geometry": polygons[code],
            "properties": {
                "citykey": p["CITYKEY"], "secteur": code, "lib": p.get("LIB"),
                "hour": h % 24,           # 0-23, clock hour
                "hour_rank": h - 3,       # 1-24, position in the Mobiliscope day (4 am first)
                "pop_presente": p.get(f"pop0_h{h}"),
                "pop_par_km2": density[code].get(f"pop0_h{h}"),
            },
        })

out_dir.mkdir(parents=True, exist_ok=True)
for name, feats in (("secteurs", sectors), ("presence", presence)):
    fc = {"type": "FeatureCollection", "name": f"{city}_{name}", "features": feats}
    (out_dir / f"{city}_{name}.geojson").write_text(json.dumps(fc), encoding="utf-8")
    print(f"{city}_{name}: {len(feats)} features")
