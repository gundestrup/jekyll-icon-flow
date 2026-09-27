# frozen_string_literal: true

module Jekyll
  module IconFlow
    module Adapters
      # Lucide (ISC license) — stroke-based UI icons vendored in
      # assets/icons/lucide/. https://lucide.dev
      class Lucide < Adapter
        COLOR_MODEL = :stroke

        def pack_name
          "lucide"
        end

        def path_for(icon_name)
          path = File.join(icons_dir, "#{icon_name}.svg")
          File.file?(path) ? path : nil
        end

        private

        def icons_dir
          File.expand_path("../../../../assets/icons/lucide", __dir__)
        end
      end
    end
  end
end
