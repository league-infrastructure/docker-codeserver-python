
.PHONY: build push ver

VERSION := "1.20250310.1"

ver:
	@echo $(VERSION)

push:
	git commit --allow-empty -a -m "Release version $(VERSION)"
	git push
	git tag v$(VERSION) 
	git push --tags

build:
	docker compose build --no-cache 

