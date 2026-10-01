install:
	go build -o ~/.steampipe/plugins/hub.steampipe.io/plugins/theapsgroup/gitlab@latest/steampipe-plugin-gitlab.plugin

# Build the plugin as a standalone Postgres FDW extension
# (steampipe_postgres_gitlab.so + .control + .sql in build/postgres/) using
# turbot/steampipe-postgres-fdw. Requires pg_config on PATH.
#
# The FDW is pinned: its main branch has moved to steampipe-plugin-sdk v6, and this plugin is on
# v5 (see go.mod), so an unpinned clone fails to compile with a PluginFunc type mismatch. v2.2.6 is
# the last release on v5.
FDW_VERSION ?= v2.2.6

postgres:
	rm -rf build/steampipe-postgres-fdw && mkdir -p build
	git clone --quiet --depth 1 --branch $(FDW_VERSION) https://github.com/turbot/steampipe-postgres-fdw.git build/steampipe-postgres-fdw
	cd build/steampipe-postgres-fdw && \
		$(MAKE) prebuild.go && \
		rm -rf work && mkdir -p work && rsync -a --exclude='.git' . work/
	cd build/steampipe-postgres-fdw/work && \
		go run generate/generator.go templates . gitlab "" github.com/theapsgroup/steampipe-plugin-gitlab && \
		echo 'replace github.com/theapsgroup/steampipe-plugin-gitlab => $(CURDIR)' >> go.mod && \
		go mod tidy && \
		$(MAKE) -C ./fdw clean plugin=gitlab && \
		$(MAKE) -C ./fdw go plugin=gitlab && \
		$(MAKE) -C ./fdw plugin=gitlab && \
		$(MAKE) -C ./fdw standalone plugin=gitlab
	rm -rf build/postgres && mkdir -p build/postgres
	cp -a build/steampipe-postgres-fdw/work/build-$(shell uname)/* build/postgres/
	@echo "Built build/postgres/ (steampipe_postgres_gitlab extension)"

clean:
	rm -rf build
