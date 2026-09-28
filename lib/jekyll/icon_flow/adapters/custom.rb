# frozen_string_literal: true

module Jekyll
  module IconFlow
    module Adapters
      # Custom — arbitrary SVGs provided by the site in
      # icon_flow.custom_dir (default "assets/icons/custom"). This is
      # the adapter for sources without a bundleable package, e.g.
      # downloads from https://www.svgrepo.com/. It also serves named
      # extra packs declared in icon_flow.packs (name → site-relative
      # directory), so a downloaded library like Font Awesome or Tabler
      # gets a pack without gem code.
      class Custom < Adapter
        COLOR_MODEL = :auto

        attr_reader :pack_name

        def initialize(site = nil, pack_name: "custom", dir: nil)
          super(site)
          @pack_name = pack_name
          @dir = dir
        end

        def path_for(icon_name)
          path = File.join(icons_dir, "#{icon_name}.svg")
          File.file?(path) ? path : nil
        end

        private

        def icons_dir
          dir = @dir || @site&.config&.dig("icon_flow", "custom_dir") || "assets/icons/custom"
          File.expand_path(dir, @site&.source || Dir.pwd)
        end
      end
    end
  end
end
