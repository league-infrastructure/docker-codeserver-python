
.PHONY: build push ver

# Single source of truth for the version is config/dotconfig.yaml.
# Update it with `dotconfig version bump` (do not edit by hand).
VERSION := $(shell awk '/^version:/ {print $$2}' config/dotconfig.yaml)

ver:
	@echo $(VERSION)

push:
	git commit --allow-empty -a -m "Release version $(VERSION)"
	git push
	git tag v$(VERSION) 
	git push --tags

build:
	DOCKER_BUILDKIT=1  docker compose build 
	docker tag docker-codeserver-python code-server-python:latest
	docker tag code-server-python:latest code-server-python:$(VERSION)


