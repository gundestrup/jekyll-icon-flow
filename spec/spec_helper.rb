# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'jekyll-icon-flow'
require 'liquid'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end

# Minimal stand-in for a Jekyll site object — the tags only need
# #config (Hash) and #source (String).
FakeSite = Struct.new(:config, :source)

def liquid_context(site: nil, vars: {})
  ctx = Liquid::Context.new(vars)
  ctx.registers[:site] = site || FakeSite.new({}, Dir.pwd)
  ctx
end

def render_tag(markup, site: nil, vars: {})
  Liquid::Template.parse("{% #{markup} %}").render(liquid_context(site: site, vars: vars))
end

# render! raises tag errors instead of emitting "Liquid error: internal"
def render_tag!(markup, site: nil, vars: {})
  Liquid::Template.parse("{% #{markup} %}").render!(liquid_context(site: site, vars: vars))
end
