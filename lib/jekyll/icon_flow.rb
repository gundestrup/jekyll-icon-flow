# frozen_string_literal: true

require "jekyll"
require "liquid"

require_relative "icon_flow/version"
require_relative "icon_flow/error"
require_relative "icon_flow/svg_reader"
require_relative "icon_flow/adapter"
require_relative "icon_flow/adapters/lucide"
require_relative "icon_flow/adapters/simple"
require_relative "icon_flow/adapters/custom"
require_relative "icon_flow/icon_tag"
require_relative "icon_flow/icon_ref_tag"

module Jekyll
  module IconFlow
    # Registry of icon pack adapters. Adding a pack means adding an
    # adapter class and an entry here — its {% icon_<key> %} tag is
    # registered automatically.
    ADAPTERS = {
      "lucide" => Adapters::Lucide,
      "simple" => Adapters::Simple,
      "custom" => Adapters::Custom
    }.freeze
  end
end

Jekyll::IconFlow::ADAPTERS.each_key do |key|
  tag = Jekyll::IconFlow::IconTag.for(key)
  Liquid::Template.register_tag("icon_#{key}", tag)
  # Fleet-convention aliases (jekyll-lucide uses {% lucide_icon %})
  Liquid::Template.register_tag("#{key}_icon", tag)
end
Liquid::Template.register_tag("icon", Jekyll::IconFlow::IconTag)
Liquid::Template.register_tag("icon_ref", Jekyll::IconFlow::IconRefTag)
