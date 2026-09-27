# frozen_string_literal: true

module Jekyll
  module IconFlow
    module Adapters
      # simple-icons (CC0) — brand/logo icons vendored in
      # assets/icons/simple/. https://simpleicons.org
      class Simple < Adapter
        COLOR_MODEL = :fill

        def pack_name
          "simple"
        end

        def path_for(icon_name)
          path = File.join(icons_dir, "#{icon_name}.svg")
          File.file?(path) ? path : nil
        end

        private

        def icons_dir
          File.expand_path("../../../../assets/icons/simple", __dir__)
        end
      end
    end
  end
end
