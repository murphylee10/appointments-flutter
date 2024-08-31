.PHONY: run
run:
	flutter run -d windows

.PHONY: build
build:
	flutter build windows

.PHONY: clean
clean:
	flutter clean

# get deps
.PHONY: get
get:
	flutter pub get

.PHONY: create
create:
	flutter create .
	
# analyze dart code for issues
.PHONY: analyze
analyze:
	flutter analyze

.PHONY: test
test:
	flutter test

# formatter
.PHONY: format
format:
	flutter format .

# install deps, build, and run
.PHONY: all
all: get analyze build run
