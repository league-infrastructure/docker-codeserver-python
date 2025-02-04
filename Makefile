
.PHONY: setup build publish compile


VERSION := "0.3.7"

ver:
	@echo $(VERSION)

push:
	git commit --allow-empty -a -m "Release version $(VERSION)"
	git push
	git tag v$(VERSION) 
	git push --tags



