# frozen_string_literal: true

require "jekyll"
require "liquid"

require_relative "icon_flow/version"
require_relative "icon_flow/error"
require_relative "icon_flow/adapter"
require_relative "icon_flow/adapters/lucide"
require_relative "icon_flow/adapters/simple"
require_relative "icon_flow/adapters/custom"
require_relative "icon_flow/icon_tag"

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
  Liquid::Template.register_tag("icon_#{key}", Jekyll::IconFlow::IconTag.for(key))
end
Liquid::Template.register_tag("icon", Jekyll::IconFlow::IconTag)
