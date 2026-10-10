# Mobiliscope, local reproduction. See README_setup.md.
DATA_ZIP  = zenodo/20230706opendata.zip
DATA_DIR  = zenodo/opendata/20230706_opendata
ZIP_URL   = https://zenodo.org/api/records/11111161/files/20230706opendata.zip/content
ZIP_MD5   = 31b064bcbcb14aa44bb962e4c96cc484
MINOR     = 20230706opendata

.PHONY: clone data config up load-data check down clean api-data api-up api-publish api-check api-down

clone:            ## clone the two public repositories
	[ -d www ] || git clone https://gitlab.huma-num.fr/mobiliscope/www.git www
	[ -d data-process ] || git clone https://gitlab.huma-num.fr/mobiliscope/data-process.git data-process

data:             ## download (4.6 GB), verify and unzip (15 GB) the open data
	mkdir -p zenodo/opendata
	[ -f $(DATA_ZIP) ] || curl -L --fail --retry 5 -C - -o $(DATA_ZIP) "$(ZIP_URL)"
	echo "$(ZIP_MD5)  $(DATA_ZIP)" | md5sum -c -
	[ -d $(DATA_DIR) ] || unzip -q $(DATA_ZIP) -d zenodo/opendata

config:           ## the gitignored key file the code includes (empty key)
	[ -f www/api_keys.php ] || cp config/api_keys.php www/api_keys.php

up: config        ## start MinIO and the web server
	docker compose up -d --build minio web

load-data:        ## create the bucket and upload the data through the S3 API
	docker compose run --rm mc mb --ignore-existing local/mobiliscope
	docker compose run --rm mc mirror --overwrite --quiet /import/ local/mobiliscope/zenodo/$(MINOR)/ > /dev/null
	docker compose run --rm mc du local/mobiliscope

check:            ## smoke test: pages and one data file answer
	@for u in /fr /fr/geoviz/rennes /en/geoviz/toulouse /es/geoviz/bogota \
	  "/minio-ajax-loader.php?path=zenodo/$(MINOR)/rennes&file=segreg/sex_Duncan.csv"; do \
	  printf "%-80s " "$$u"; curl -s -o /dev/null -w "%{http_code} %{size_download}B\n" "http://127.0.0.1:8090$$u"; done
	@curl -s http://127.0.0.1:8090/fr/geoviz/rennes | grep -c -E "<b>(Warning|Fatal error)</b>" | sed 's/^/PHP warnings in page: /'

down:             ## stop, keep the data volume
	docker compose down

clean:            ## stop and delete the MinIO volume (the unzipped data stay on disk)
	docker compose --profile tools down -v

# --- Optional OGC API prototype, see ogcapi/README_api.md -------------------
CITY ?= toulouse
GS    = http://127.0.0.1:8600/geoserver
OGC   = $(GS)/mobiliscope/ogc/features/v1

api-data:         ## long-form layers and GeoPackage for one city (needs python3 and GDAL)
	python3 ogcapi/prepare_data.py $(DATA_DIR)/$(CITY) ogcapi/data
	rm -f ogcapi/data/$(CITY).gpkg
	ogr2ogr -f GPKG ogcapi/data/$(CITY).gpkg ogcapi/data/$(CITY)_secteurs.geojson -nln $(CITY)_secteurs -a_srs EPSG:4326
	ogr2ogr -f GPKG -update ogcapi/data/$(CITY).gpkg ogcapi/data/$(CITY)_presence.geojson -nln $(CITY)_presence -a_srs EPSG:4326

api-up:           ## start GeoServer and wait until it answers (first start downloads the OGC API module)
	docker compose --profile api up -d geoserver
	@printf "waiting for GeoServer "; for i in $$(seq 1 90); do \
	  curl -s -o /dev/null -f $(GS)/web/ && break; printf "."; sleep 2; done; echo " up"

api-publish:      ## create workspace, datastore and layers through the REST API
	CITY=$(CITY) GS=$(GS) ogcapi/publish.sh

api-check:        ## smoke test of the OGC API - Features endpoints
	@for u in "" "/conformance" "/collections" "/collections/$(CITY)_secteurs/items?f=application%2Fgeo%2Bjson&limit=1000" \
	  "/collections/$(CITY)_presence/items?f=application%2Fgeo%2Bjson&limit=1000&filter=hour%3D14"; do \
	  printf "%-110s " "$$u"; curl -s -o /dev/null -w "%{http_code} %{size_download}B\n" "$(OGC)$$u"; done
	@python3 ogcapi/check_api.py $(OGC) $(CITY) $(DATA_DIR)

api-down:         ## stop GeoServer (its configuration lives in the container and is lost)
	docker compose --profile api rm -sf geoserver
