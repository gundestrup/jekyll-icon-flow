# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless ENV["COVERAGE"] == "false"
  require "simplecov"
  if ENV["CI"]
    require "simplecov-cobertura"
    SimpleCov.formatter SimpleCov::Formatter::MultiFormatter.new(
      [SimpleCov::Formatter::CoberturaFormatter, SimpleCov::Formatter::JSONFormatter]
    )
  end
  SimpleCov.start do
    cover "lib/**/*.rb"
    minimum_coverage 90 if ENV["CI"]
  end
end

require "jekyll-icon-flow"
require "jekyll_test_harness"
require "liquid"

JekyllTestHarness.install!(framework: :rspec)

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end

# Real Jekyll::Site (host-object testing, not mocks). Source points at
# spec/fixtures so the custom adapter can read fixture SVGs; destination
# is a throwaway dir — nothing is ever built.
def make_site(config = {})
  Jekyll::Site.new(Jekyll.configuration(
                     {
                       "source" => File.expand_path("fixtures", __dir__),
                       "destination" => File.expand_path("fixtures/_site", __dir__)
                     }.merge(config)
                   ))
end

def liquid_context(site: nil, vars: {})
  ctx = Liquid::Context.new(vars)
  ctx.registers[:site] = site || make_site
  ctx
end

def render_tag(markup, site: nil, vars: {})
  Liquid::Template.parse("{% #{markup} %}").render(liquid_context(site: site, vars: vars))
end

# render! raises tag errors instead of emitting "Liquid error: internal"
def render_tag!(markup, site: nil, vars: {})
  Liquid::Template.parse("{% #{markup} %}").render!(liquid_context(site: site, vars: vars))
end
