# frozen_string_literal: true

require "cgi"

module Jekyll
  module IconFlow
    # Base icon-pack adapter. Resolves an icon name to an SVG file and
    # normalizes the markup so every pack shares the same styling contract:
    #
    #   * class "icon icon-<name>" merged into the root element
    #   * fixed width/height attributes removed; size via inline style
    #     (default 1em) so the icon scales with surrounding text
    #   * color normalized to currentColor according to the pack's
    #     COLOR_MODEL (:stroke, :fill, or :auto for arbitrary SVGs)
    #   * data-icon-pack="<pack>" and role="img" on the root element
    class Adapter
      COLOR_MODEL = :auto

      ICON_NAME = /\A[a-z0-9_-]+\z/
      CSS_SIZE = /\A(?:0|(?:\d+(?:\.\d+)?|\.\d+)(?:px|em|rem|%|vw|vh|vmin|vmax|ch|ex))\z/i

      def initialize(site = nil)
        @site = site
      end

      def pack_name
        raise NotImplementedError
      end

      # Absolute path of the SVG for icon_name, or nil when the pack
      # does not contain it.
      def path_for(_icon_name)
        raise NotImplementedError
      end

      def icon_names
        return [] unless Dir.exist?(icons_dir)

        Dir.children(icons_dir).grep(/\.svg\z/).map { |f| f.delete_suffix(".svg") }.sort
      end

      def render(icon_name, options = {})
        name = icon_name.to_s.strip.downcase
        raise Error, "invalid icon name '#{icon_name}'" unless name.match?(ICON_NAME)

        path = path_for(name)
        raise Error, "icon '#{name}' not found in pack '#{pack_name}'" unless path

        normalize(File.read(path), name, options)
      end

      private

      def icons_dir
        raise NotImplementedError
      end

      def normalize(svg, icon_name, options)
        svg = svg.strip.sub(/\A<\?xml[^?]*\?>\s*/, "")
        svg = normalize_custom_colors(svg) if self.class::COLOR_MODEL == :auto
        svg = svg.sub(/<svg[^>]*>/) { |tag| normalize_root(tag, icon_name, options) }
        options["title"] ? inject_title(svg, options["title"].to_s) : svg
      end

      def normalize_root(tag, icon_name, options)
        size = (options["size"] || "1em").to_s
        raise Error, "invalid icon size '#{size}'" unless size.match?(CSS_SIZE)

        tag = tag.gsub(/\s+(width|height)="[^"]*"/, "")
        classes = "icon icon-#{icon_name} #{options['class']}".strip
        tag = ensure_attr(tag, "class", CGI.escapeHTML(classes))
        tag = merge_style(tag, "width:#{size};height:#{size}")
        tag = normalize_color(tag)
        tag = ensure_attr(tag, "data-icon-pack", pack_name)
        ensure_attr(tag, "role", "img")
      end

      def normalize_custom_colors(svg)
        svg.gsub(/(\s)(fill|stroke)=(['"])(.*?)\3/) do
          space, name, quote, value = Regexp.last_match.captures
          %(#{space}#{name}=#{quote}#{preserve_color?(value) ? value : 'currentColor'}#{quote})
        end
      end

      def preserve_color?(value)
        value == "none" || value == "currentColor" || value.start_with?("url(")
      end

      def inject_title(svg, title)
        svg.sub(/<svg[^>]*>/) { |tag| "#{tag}<title>#{CGI.escapeHTML(title)}</title>" }
      end

      # :stroke packs (lucide) already carry stroke="currentColor";
      # :fill packs (simple-icons) get fill on the root so paths inherit;
      # :auto (custom) only injects fill when the SVG declares neither.
      def normalize_color(tag)
        case self.class::COLOR_MODEL
        when :stroke then ensure_attr(tag, "stroke", "currentColor")
        when :fill then ensure_attr(tag, "fill", "currentColor")
        else tag =~ /\s(fill|stroke)=/ ? tag : tag.sub("<svg", '<svg fill="currentColor"')
        end
      end

      def ensure_attr(tag, attr, value)
        if tag =~ /\s#{attr}="([^"]*)"/
          attr == "class" ? tag.sub(/class="([^"]*)"/, %(class="\\1 #{value}")) : tag
        else
          tag.sub("<svg", %(<svg #{attr}="#{value}"))
        end
      end

      def merge_style(tag, style)
        if tag =~ /\sstyle="([^"]*)"/
          tag.sub(/style="([^"]*)"/, %(style="\\1;#{style}"))
        else
          tag.sub("<svg", %(<svg style="#{style}"))
        end
      end
    end
  end
end
