# Mobiliscope: local reproduction on Linux with Docker

Linda Angulo Lopez, 1 October 2026

A local copy of the Mobiliscope website (v4.3) running over the open data published on Zenodo, set up to learn how the tool is built. It is an independent exercise: it is not part of the Mobiliscope project and nothing here has been reported upstream. In the working folder, two untracked files are added to each clone: `api_keys.php` (in `www` only, needed to run) and a draft `codemeta.json`. The clones and the data are not redistributed in this repository; `make clone` and `make data` fetch them.

## Result

| | |
|---|---|
| Website | **Works.** Home page, information pages and the geovisualisation for all 60 city folders, in French, English and Spanish, at http://127.0.0.1:8090 |
| Map, timeline, charts, segregation indices | **Work**, checked on Rennes, Toulouse and Bogotá |
| Default basemap (CARTO) | **Degraded.** Tiles show "API key required". The project's key is private. Sectors and data draw correctly on top |
| "Oursins" flow view | **Not available.** `flowData` is not in the open data, for confidentiality. Expected, and stated in the Zenodo readme |
| R pipeline (`data-process`) | **Not run.** Its inputs are confidential survey microdata. Read and checked statically only |
| Duncan index | **Reproduced.** Recomputed in R from the open data for Rennes and Toulouse: 912 values per city, all equal to the published values to the fourth decimal |

Screenshots: `screenshots/rennes_local.png`, `screenshots/toulouse_local.png`.

## What is in this folder

```
www/              clone of gitlab.huma-num.fr/mobiliscope/www          (AGPL-3.0; no tracked file changed)
data-process/     clone of gitlab.huma-num.fr/mobiliscope/data-process (AGPL-3.0; no tracked file changed)
zenodo/           open data, doi:10.5281/zenodo.11111161 (ODbL): zip, readme, unzipped folder
config/           .env, settings.json, api_keys.php (local values only)
docker/           Dockerfile.web
docker-compose.yml
Makefile
r_check/          duncan_check.R and its outputs
screenshots/
README_setup.md   this file
CODEMETA_notes.md notes on the draft codemeta.json files (CodeMeta 4.0)
codemeta/         the two draft codemeta.json files
```

Versions used:

| Component | Version |
|---|---|
| `www` | branch `master`, commit `1f7929e` (1 Oct 2026) |
| `data-process` | branch `main`, commit `d457f72` (8 Apr 2026) |
| Open data | `20230706opendata.zip`, 4.58 GB, md5 `31b064bcbcb14aa44bb962e4c96cc484` (matches Zenodo) |
| PHP / Apache | 7.4.33 / 2.4.54, image `php:7.4-apache` |
| MinIO server | RELEASE.2026-09-22, image `cgr.dev/chainguard/minio` |
| R | 4.6.1 (host) |

## Setup from scratch

Needs: Docker with Compose, git, curl, unzip, about **21 GB** of disk (4.6 GB zip, 15 GB unzipped, images), and about **25 minutes**, almost all of it the download.

```bash
cd ~/Documents/myData/mobiliscope
make clone        # the two repositories
make data         # download, checksum, unzip
make up           # build the web image, start MinIO and Apache
make load-data    # create the bucket, upload 12,334 files (about 15 seconds)
make check        # smoke test
```

Then open http://127.0.0.1:8090/fr/geoviz/rennes.

Other commands: `make down` stops the containers and keeps the data; `make clean` also deletes the MinIO volume. The MinIO console is at http://127.0.0.1:9011 (login `admin` / `password`, local only).

Rebuild test, done once on 1 October: `make clean`, then `make up` and `make load-data` took 18 seconds, and `make check` returned HTTP 200 on all five URLs with no PHP warning in the page.

## How it fits together

```
browser ──> Apache + PHP 7.4 (container "web", port 8090)
               │  .htaccess rewrites /fr/geoviz/<city> to french/geoviz/geoviz.php
               │  minio-ajax-loader.php?path=...&file=...   reads one object
               ▼
            MinIO (container "minio", S3 API)
               bucket "mobiliscope" / zenodo / 20230706opendata / <city> / {geo, stacked, segreg, layers, menu.json, paramgeom.js}
```

The site has no database. Every map layer and chart is a CSV, GeoJSON or JSON file read from the S3 bucket by a PHP script, through the AWS SDK committed in `www/vendor/`. The built JavaScript is committed in `www/dist/`, so Node and Webpack are only needed to change the front-end code.

## Where this differs from the admin guide (v4.3, section 2.6)

The guide documents a Windows install with WampServer. On Linux with containers:

| Guide | Here | Why |
|---|---|---|
| WampServer 3.3.0 on Windows | `php:7.4-apache` container, with `mod_rewrite`, `mod_headers` and `AllowOverride All` | Same PHP and Apache major versions, no host install. The routing lives in `www/.htaccess`, so overrides must be allowed |
| `minio.exe` downloaded from min.io | `cgr.dev/chainguard/minio` | **The official download no longer exists.** On 1 Oct 2026, `dl.min.io` answers HTTP 410, `minio/minio` is gone from Docker Hub, and `quay.io/minio/minio` refuses anonymous pulls |
| `minioEndPoint: http://127.0.0.1:9000` | `http://minio:9000` | PHP runs in a container; it reaches MinIO by service name, not through the host |
| Upload through the MinIO web console | `mc mirror` through the S3 API | Same effect, scriptable. The guide's warning stands: never copy files straight into MinIO's data folder |
| `.env` and `settings.json` created by hand next to `www/` | Kept in `config/`, mounted read-only at `/var/www/.env` and `/var/www/settings.json` | The code reads `__DIR__ . '/../.env'` |
| `minorVersion: "20230706opendata"` | Same, but the zip unpacks to `20230706_opendata` (with an underscore) | The upload target is renamed in the Makefile |
| Not mentioned | `www/api_keys.php` with `$carto_api = "";` | See problem 2 below |
| Webpack build | Skipped | `dist/` is committed |

## Problems met, and how each was solved

1. **MinIO cannot be installed as documented.** See the table above. Solved with the Chainguard builds. Any S3-compatible server would do, since the PHP only speaks S3.
2. **The map never drew; the page showed a spinner.** `french/geoviz/geoviz.php` line 55 does `include("../../api_keys.php")`. That file is in `www/.gitignore` and is not mentioned in the guide or the readme. Without it PHP prints a warning *inside a `<script>` block*, the browser reports `Unexpected token '<'`, `cartoApiKey` is never defined, and `load.js` stops. Solved with a one-line stub copied to `www/api_keys.php` (gitignored, so the clone stays clean).
3. **Grey tiles marked "API key required".** With an empty key the code falls back to the keyless CARTO URL, which CARTO no longer serves. Not solved: it needs a CARTO key. The "fond de carte détaillé" (OpenStreetMap) layer in the map's layer menu is the workaround.
4. **A read-only mount cannot receive a new file.** Mounting the stub into the read-only `www` bind mount failed. Solved by copying the stub into the clone.
5. **Root-owned folder.** Docker created the import folder as root before the data existed, and `unzip` then failed with "Permission denied". Solved by unzipping first (the Makefile order: `data` before `load-data`).
6. **Ports.** 8080 and 8088 were already taken on this machine; the site is on 8090, MinIO on 9010/9011, all bound to 127.0.0.1.

## The R check

```bash
cd r_check
Rscript duncan_check.R rennes
Rscript duncan_check.R toulouse
```

The script reads the number of people present per sector and hour (`stacked/<indicator>_prop_stacked.csv`), computes Duncan's segregation index for each group and hour with the formula written out by hand, and compares with `segreg/<indicator>_Duncan.csv`. Result for both cities: ten indicators, 912 values, largest difference 0.00005, which is the rounding of the published four decimals.

What this shows: the published indices follow from the published counts, and the method in `p2m_fct.R` (`OasisR::ISDuncan`) is the one described on the website. What it does not show: anything about the steps before, from the raw surveys to the counts.

The Moran index was not recomputed. It needs `spdep` and a permutation test, so values would match only approximately.

## The R pipeline, read but not run

- 25 R scripts and 3 Quarto documents, about 18,900 lines, in three stages: raw survey to mobility table (`step1`, one script per survey family), trips to presence (`step2/d2p.R`), presence to the files the site reads (`step3/p2m.R`).
- 36 packages are loaded. On this machine 23 are installed. Of the 13 missing, 11 are on CRAN (`tidylog`, `skimr`, `TraMineR`, `areal`, `spdep`, `rmapshaper`, `OasisR`, `lwgeom`, `geojsonio`, `chron`, `aws.s3`) and 2 are not (`COGugaison`, `minio.s3`, both GitHub only).
- Inputs are expected in a folder outside the repository (`../../../../00_BD_mobiliscope`), which holds the confidential survey data. Without it nothing in `step1` to `step3` can run.

## Limits of this reproduction

- It reproduces the published site from the published outputs. It does not reproduce the outputs from the sources.
- Checked by request and by screenshot on three cities; not every indicator of every city was opened.
- Images are pulled by `latest` tag, so a later rebuild may get newer MinIO builds.
- `php:7.4-apache` is an unmaintained image (PHP 7.4 reached end of life in November 2022). Fine on localhost, not for anything exposed.
