export GOBIN ?= $(shell pwd)/bin

GO_FILES := $(shell \
	find . '(' -path '*/.*' -o -path './vendor' ')' -prune \
	-o -name '*.go' -print | cut -b3-)

GOLINT = $(GOBIN)/golint
STATICCHECK = $(GOBIN)/staticcheck
GOLINT2 = $(GOBIN)/golangci-lint

.PHONY: build
build:
	go build ./...

.PHONY: install
install:
	go mod download

.PHONY: test
test:
	go test -race ./...

.PHONY: cover
cover:
	go test -coverprofile=cover.out -covermode=atomic -coverpkg=./... ./...
	go tool cover -html=cover.out -o cover.html

$(GOLINT): tools/go.mod
	cd tools && go install golang.org/x/lint/golint@latest

$(GOLINT2): tools/go.mod
	cd tools && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

$(STATICCHECK): tools/go.mod
	cd tools && go install honnef.co/go/tools/cmd/staticcheck@latest

.PHONY: lint
lint: $(GOLINT) $(GOLINT2) $(STATICCHECK)
	@rm -rf lint.log
	@echo "Checking gofmt"
	@gofmt -d -s $(GO_FILES) 2>&1 | tee lint.log
	@echo "Checking go vet"
	@go vet ./... 2>&1 | tee -a lint.log
	@echo "Checking golint"
	@$(GOLINT) ./... | tee -a lint.log
	@echo "Checking golint2"
	@$(GOLINT2) run ./... | tee -a lint.log
	@echo "Checking staticcheck"
	@$(STATICCHECK) ./... 2>&1 |  tee -a lint.log
	@echo "Checking for license headers..."
	@./.build/check_license.sh | tee -a lint.log
	@[ ! -s lint.log ]

.PHONY: lint2
lint2:
	@go run github.com/golangci/golangci-lint/cmd/golangci-lint@latest run --fix
	@go run mvdan.cc/gofumpt@latest -w -l .
	@go run github.com/dkorunic/betteralign/cmd/betteralign@latest -test_files -generated_files -apply ./...
