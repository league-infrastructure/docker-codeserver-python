
.PHONY: build push ver

VERSION := "1.20250926.1"

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


