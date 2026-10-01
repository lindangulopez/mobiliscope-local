# Mobiliscope, local reproduction. See README_setup.md.
DATA_ZIP  = zenodo/20230706opendata.zip
DATA_DIR  = zenodo/opendata/20230706_opendata
ZIP_URL   = https://zenodo.org/api/records/11111161/files/20230706opendata.zip/content
ZIP_MD5   = 31b064bcbcb14aa44bb962e4c96cc484
MINOR     = 20230706opendata

.PHONY: clone data config up load-data check down clean

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
