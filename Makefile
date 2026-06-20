
.PHONY: build push release ver

# The version is owned by config/dotconfig.yaml (single source of truth).
# Bump it with `make release` (or `dotconfig version bump`) — never edit by hand.
VERSION := $(shell awk '/^version:/ {print $$2}' config/dotconfig.yaml)
TAG     := v$(VERSION)

ver:
	@echo $(VERSION)

# Cut a release: bump to a brand-new version (dotconfig updates dotconfig.yaml
# and package.json), then commit, tag, and push. A unique version every time
# means a never-before-pushed tag — which is exactly what triggers the GHCR
# build workflow (.github/workflows/docker-publish.yml). This is the normal path.
release:
	@git diff --quiet && git diff --cached --quiet || { echo "Working tree has uncommitted changes — commit or stash first."; exit 1; }
	dotconfig version bump
	@$(MAKE) --no-print-directory push

# Commit the current version files, then tag and push the tag. Refuses to run if
# the tag already exists, so a non-bumped version can't silently no-op (the old
# bug that left master moving with no new tag and therefore no build). Normally
# invoked via `make release`; run directly only if you bumped the version yourself.
push:
	@if git rev-parse -q --verify "refs/tags/$(TAG)" >/dev/null 2>&1; then \
	  echo "Tag $(TAG) already exists — run 'make release' to bump to a new version."; \
	  exit 1; \
	fi
	git commit --allow-empty -a -m "Release version $(VERSION)"
	git push
	git tag $(TAG)
	git push origin $(TAG)

build:
	DOCKER_BUILDKIT=1 docker compose build
	docker tag docker-codeserver-python code-server-python:latest
	docker tag code-server-python:latest code-server-python:$(VERSION)
