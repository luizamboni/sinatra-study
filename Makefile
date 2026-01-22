.PHONY: run server dev-server seed console test rbs check

RUBY_VERSION := $(shell cat .ruby-version)

run:
	bundle exec ruby bin/run

server:
	bundle exec ruby bin/server

dev-server:
	RUBYOPT='-r debug' $(CHRB) bundle exec ruby bin/dev_server

seed:
	bundle exec ruby bin/seed

console:
	bundle exec ruby bin/console

test:
	RUBYOPT='-r debug' $(CHRB) bundle exec ruby -Iapp:test -e 'ARGV.each { |f| require File.expand_path(f) }' $(shell command -v rg >/dev/null 2>&1 && rg --files -g "*_test.rb" test || find test -name "*_test.rb")

rbs:
	bundle exec rbs validate

check: test rbs
