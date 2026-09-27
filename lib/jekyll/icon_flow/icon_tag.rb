# frozen_string_literal: true

module Jekyll
  module IconFlow
    # {% icon %} and per-pack {% icon_<pack> %} tags.
    #
    #   {% icon search %}                              default pack (icon_flow.pack)
    #   {% icon include.name pack: include.pack %}     variables resolve from context
    #   {% icon_lucide "file-text" size:1.5em class:"has-text-link" %}
    #   {% icon_simple github %}
    #   {% icon_custom logo %}
    #
    # Params: size (any CSS size, default 1em), class (merged onto the svg),
    # title (accessible label, becomes an svg <title>). The generic {% icon %}
    # also accepts pack: to pick an adapter explicitly; bound tags ignore it.
    class IconTag < Liquid::Tag
      NAME_TOKEN = /\A\s*("[^"]*"|'[^']*'|[^\s]+)/
      PARAM = /(\w+):\s*("[^"]*"|'[^']*'|[^\s]+)/

      def self.for(pack_key)
        Class.new(self) do
          define_method(:bound_pack) { pack_key }
        end
      end

      def initialize(tag_name, markup, options)
        super
        @name_token = markup[NAME_TOKEN, 1]
        @params_markup = markup[NAME_TOKEN] ? markup.delete_prefix(markup[NAME_TOKEN]) : ""
        raise Error, "icon tag requires a name" unless @name_token
      end

      def render(context)
        site = context.registers[:site]
        return "" if site&.config&.dig("icon_flow", "enabled") == false

        name = resolve(@name_token, context)
        params = parse_params(context)
        adapter_for(site, params).render(name, params)
      end

      private

      def parse_params(context)
        @params_markup.scan(PARAM).to_h do |key, value|
          [key, resolve(value, context)]
        end
      end

      # Quoted tokens are literals; bare tokens resolve through the Liquid
      # context first (so include.name works) and fall back to the literal.
      def resolve(token, context)
        return token[1..-2] if token.start_with?('"', "'")

        context[token] || token
      end

      def adapter_for(site, params)
        key = bound_pack || params.delete("pack") ||
              site&.config&.dig("icon_flow", "pack") || "lucide"
        klass = ADAPTERS[key]
        raise Error, "unknown icon pack '#{key}'" unless klass

        klass.new(site)
      end

      def bound_pack
        nil # overridden by .for subclasses
      end
    end
  end
end
