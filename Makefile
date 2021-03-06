#!/usr/bin/make -f
.PHONY: all
all: build

SHELL :=/bin/bash

GOFMT :=gofmt -s
GOIMPORTS :=goimports -e
GOFLAGS :=

GO_FILES :=$(shell find . -name '*.go' -not -path './vendor/*' -print)
GO_PACKAGES := ./ ./cmd/... ./pkg/...
GO_PACKAGES_TEST :=./test/...
GO_PACKAGES_ALL :=$(GOPACKAGES) $(GO_PACKAGES_TEST)
GO_IMPORT_PATH :=github.com/tnozicka/openshift-acme
IMAGE_NAME :=docker.io/tnozicka/openshift-acme

# we intentionaly don't specify this value because test are making changes to the cluster so we wan't user to configure it explicitely
GO_ET_KUBECONFIG :="<unspecified>"
GO_ET_DOMAIN :=""

.PHONY: build
build:
	go build $(GOFLAGS)

.PHONY: install
install:
	go install $(GOFLAGS)

.PHONY: test
test:
	go test $(GOFLAGS) $(GO_PACKAGES) 

.PHONY: test-extended
test-extended:
	go test $(GOFLAGS) $(GO_PACKAGES_TEST) -kubeconfig $(GO_ET_KUBECONFIG) -domain $(GO_ET_DOMAIN)

.PHONY: checks
checks: check-gofmt check-goimports check-govet

.PHONY: check-gofmt
check-gofmt:
	$(info Checking gofmt formating)
	@export files && files="$$(gofmt -l $(GO_FILES))" && \
	if [ -n "$${files}" ]; then printf "ERROR: These files are not formated by gofmt:\n"; printf "%s\n" $${files[@]}; exit 1; fi

.PHONY: check-goimports
check-goimports:
	$(info Checking goimports formating)
	@export files && files="$$(goimports -l $(GO_FILES))" && \
	if [ -n "$${files}" ]; then printf "ERROR: These files are not formated by goimports:\n"; printf "%s\n" $${files[@]}; exit 1; fi

.PHONY: check-govet
check-govet:
	go vet $(GO_PACKAGES_ALL)

.PHONY: check-strip-vendor
check-strip-vendor:
	@export vendors && vendors=$$(find ./vendor/ -mindepth 1 -type d -name 'vendor') && \
	if [ -n "$${vendors}" ]; then printf "ERROR: There are nested vendor directories: \n"; printf "%s\n" $${vendors[@]}; exit 1; fi
	@export files && files=$$($(do-strip-vendor) --dryrun) && \
	if [ -n "$${files}" ]; then printf "ERROR: There are unused files in ./vendor/\nRun 'make strip-vendor' to fix it.\n"; exit 1; fi

.PHONY: format
format: format-gofmt format-goimports

.PHONY: format-gofmt
format-gofmt:
	$(GOFMT) -w $(GO_FILES)

.PHONY: format-goimports
format-goimports:
	$(GOIMPORTS) -w $(GO_FILES)

do-strip-vendor :=glide-vc --only-code --no-tests --no-test-imports --no-legal-files

.PHONY: update-vendor
update-vendor:
	glide update --strip-vendor
	$(do-strip-vendor)

.PHONY: strip-vendor
strip-vendor:
	$(do-strip-vendor)

.PHONY: image
image:
	s2i build . docker.io/tnozicka/s2i-centos7-golang $(IMAGE_NAME) -e APP_URI=$(GO_IMPORT_PATH) --runtime-image=docker.io/tnozicka/s2i-centos7-golang-runtime --runtime-artifact=/opt/app-root/src/bin/app:bin/

