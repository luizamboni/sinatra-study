.PHONY: run server dev-server seed console test rbs check

RUBY_VERSION := $(shell cat .ruby-version)
CHRB := chruby-exec $(RUBY_VERSION) --

run:
	$(CHRB) bundle exec ruby bin/run

server:
	$(CHRB) bundle exec ruby bin/server

dev-server:
	RUBYOPT='-r debug' $(CHRB) bundle exec ruby bin/dev_server

seed:
	$(CHRB) bundle exec ruby bin/seed

console:
	$(CHRB) bundle exec ruby bin/console

test:
	RUBYOPT='-r debug' $(CHRB) bundle exec ruby -Iapp:test -e 'ARGV.each { |f| require File.expand_path(f) }' $(shell command -v rg >/dev/null 2>&1 && rg --files -g "*_test.rb" test || find test -name "*_test.rb")

rbs:
	$(CHRB) bundle exec rbs validate

check: test rbs
