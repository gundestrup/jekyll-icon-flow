# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development do
  gem "base64" # pre-4.3 Jekyll doesn't declare it; removed from stdlib in Ruby 3.4
  gem "bigdecimal" # liquid needs it explicitly on Ruby >= 3.4 (removed from stdlib)
  gem "bundler-audit", "~> 0.9"
  gem "csv" # pre-4.3 Jekyll doesn't declare it; removed from stdlib in Ruby 3.4
  gem "jekyll-test-harness", "0.1.0.alpha"
  gem "minitest", "~> 6.0"
  gem "minitest-mock", "~> 5.27"
  gem "rake", "~> 13.0"
  gem "rubocop", "~> 1.60"
  gem "rubocop-minitest", "~> 0.41"
  gem "simplecov", "~> 1.3"
  gem "simplecov-cobertura", "~> 4.0"
end
