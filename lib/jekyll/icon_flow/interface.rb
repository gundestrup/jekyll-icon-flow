# frozen_string_literal: true

module Jekyll
  module IconFlow
    # Machine-readable description of the plugin's public interface:
    # Liquid tags + their params, config keys, and enum values.
    # `rake interface` writes this as interface.yml (shipped in the gem) so
    # tooling like editor extensions can consume it without parsing Ruby.
    module Interface
      CONFIG_KEYS = %w[custom_dir enabled on_missing pack packs registry search].freeze
      SHARED_PARAMS = %w[class size title].freeze

      def self.to_h
        {
          "gem" => "jekyll-icon-flow", "version" => VERSION,
          "tags" => tags.sort.to_h, "filters" => [],
          "config" => { "icon_flow" => CONFIG_KEYS.sort },
          "enums" => { "packs" => ADAPTERS.keys.sort, "sizes" => Adapter::SIZES.keys,
                       "on_missing" => %w[strict warn] }
        }
      end

      def self.tags
        {
          "icon" => { "params" => (SHARED_PARAMS + %w[pack]).sort },
          "icon_ref" => { "params" => SHARED_PARAMS.dup }
        }.merge(
          ADAPTERS.keys.flat_map { |key| ["icon_#{key}", "#{key}_icon"] }
                  .to_h { |name| [name, { "params" => SHARED_PARAMS.dup }] }
        )
      end
    end
  end
end
