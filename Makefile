.PHONY: docs

docs:
	xcodebuild -target "Documentation Generation" -config Release
