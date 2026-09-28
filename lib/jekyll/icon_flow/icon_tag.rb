# frozen_string_literal: true

require "strscan"

module Jekyll
  module IconFlow
    # {% icon %} and per-pack {% icon_<pack> %} tags.
    #
    #   {% icon search %}                              default pack (icon_flow.pack)
    #   {% icon include.name pack: include["pack"] %}  variables resolve from context
    #   {% icon_lucide "file-text" size:1.5em class:"has-text-link" %}
    #   {% icon_simple github %}
    #   {% icon_custom logo %}
    #
    # Aliases matching the fleet convention (jekyll-lucide): lucide_icon,
    # simple_icon, custom_icon.
    #
    # Params: size (any CSS size, default 1em), class (merged onto the svg),
    # title (accessible label, becomes an svg <title>). The generic {% icon %}
    # also accepts pack: to pick an adapter explicitly; bound tags ignore it.
    class IconTag < Liquid::Tag
      NAME_TOKEN = /\A\s*("[^"]*"|'[^']*'|[^\s]+)/
      # A bare token that starts with a letter/underscore and contains a
      # dot or bracket is a variable path (include.pack, page.icon[0]).
      VAR_PATH = /\A[A-Za-z_]\S*[.\[]/

      def self.for(pack_key)
        Class.new(self) do
          define_method(:bound_pack) { pack_key }
        end
      end

      # The name check lives in render, not initialize: Liquid still parses
      # tags inside {% comment %} blocks, so a documented example like
      # "{% icon %}" must parse cleanly even though it never renders.
      def initialize(tag_name, markup, options)
        super
        @name_token = markup[NAME_TOKEN, 1]
        @params_markup = markup[NAME_TOKEN] ? markup.delete_prefix(markup[NAME_TOKEN]) : ""
      end

      def render(context)
        site = context.registers[:site]
        return "" if site&.config&.dig("icon_flow", "enabled") == false

        name, params = name_and_params(context)
        render_icon(site, name, params)
      rescue Error => e
        missing!(site, e)
      end

      private

      def name_and_params(context)
        raise Error, "icon tag requires a name" unless @name_token

        [resolve(@name_token, context), parse_params(context)]
      end

      # Missing icons are untrusted user input — report via the host logger
      # and render empty by default (icon_flow.on_missing: warn). Set
      # on_missing: strict to fail the build instead.
      def missing!(site, error)
        raise error if site&.config&.dig("icon_flow", "on_missing") == "strict"

        Jekyll.logger.warn("icon_flow:", error.message)
        ""
      end

      def parse_params(context)
        scanner = StringScanner.new(@params_markup)
        params = {}
        until scanner.eos?
          key, value = next_param(scanner)
          next unless key && value

          resolved = resolve(value, context, allow_nil: true)
          params[key.delete_suffix(":")] = resolved unless resolved.nil?
        end
        params
      end

      def next_param(scanner)
        scanner.skip(/\s+/)
        key = scanner.scan(/\w+:/)
        unless key
          scanner.pos += 1 unless scanner.eos?
          return nil
        end

        scanner.skip(/\s*/)
        [key, scanner.scan(/"[^"]*"|'[^']*'|\S+/)]
      end

      # Quoted tokens are literals; bare tokens resolve through the Liquid
      # context first (so include.name works) and fall back to the literal.
      # Unresolved variable paths in params are treated as absent so a
      # wrapper include can forward optional params unconditionally —
      # literal values (icon names, "1.5em") never match VAR_PATH.
      def resolve(token, context, allow_nil: false)
        return token[1..-2] if token.start_with?('"', "'")

        value = context[token]
        return nil if allow_nil && value.nil? && token.match?(VAR_PATH)

        value || token
      end

      # The unbound {% icon %} tag searches packs in order and renders the
      # first hit — custom_dir and named icon_flow.packs dirs, then the
      # bundled packs (default chain: custom → simple → lucide, so a brand
      # name like "github" just works). pack: or icon_flow.pack pin the
      # lookup to a single pack; bound {% icon_<pack> %} tags always use
      # their own pack only.
      def render_icon(site, name, params)
        keys = candidate_keys(site, params)
        adapters = keys.map { |key| adapter_instance(site, key) }
        hit = adapters.find { |adapter| adapter.path_for(name) }
        return hit.render(name, params) if hit

        plural = keys.size == 1 ? "pack" : "packs"
        raise Error, "icon '#{name}' not found in #{plural} '#{keys.join(', ')}'"
      end

      def candidate_keys(site, params)
        return [bound_pack] if bound_pack
        return [params.delete("pack").to_s] if params["pack"]

        pack = site&.config&.dig("icon_flow", "pack")
        pack ? [pack.to_s] : search_keys(site)
      end

      def search_keys(site)
        search = site&.config&.dig("icon_flow", "search")
        search = %w[custom simple lucide] if search.nil? || search.empty?
        Array(search).map(&:to_s)
      end

      # Built-in packs instantiate their own class; any other name resolves
      # through icon_flow.packs (name → site-relative dir of *.svg files).
      def adapter_instance(site, key)
        klass = ADAPTERS[key]
        return klass.new(site) if klass

        dir = site&.config&.dig("icon_flow", "packs", key)
        return Adapters::Custom.new(site, pack_name: key, dir: dir) if dir

        raise Error, "unknown icon pack '#{key}'"
      end

      def bound_pack
        nil # overridden by .for subclasses
      end
    end
  end
end
