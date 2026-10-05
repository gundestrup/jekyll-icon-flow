# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# Contract test: the same normalized output shape must hold for every
# registered adapter — swap packs, keep styling (adapter-contract-testing
# pattern).
CONTRACT_ICONS = {
  "lucide" => "search",
  "simple" => "github",
  "custom" => "star"
}.freeze

RSpec.describe "adapter output contract" do
  it "recolors hard-coded colors on child elements without changing fill=none" do
    adapter = Jekyll::IconFlow::Adapters::Custom.new
    svg = '<svg viewBox="0 0 1 1"><path fill="#ff0000" stroke="blue" d="M0 0"/>' \
          '<path fill="none" stroke="url(#gradient)" d="M1 1"/></svg>'
    html = adapter.send(:normalize, svg, "star", {})
    expect(html).to include('<path fill="currentColor" stroke="currentColor"')
    expect(html).to include('fill="none" stroke="url(#gradient)"')
  end

  # User-supplied SVGs (custom_dir, icon_flow.packs) are bytes of unknown
  # provenance — a Latin-1 download must not crash the build.
  describe "SVG byte encoding" do
    def render_bytes(bytes)
      Dir.mktmpdir do |dir|
        File.binwrite(File.join(dir, "icon.svg"), bytes)
        Jekyll::IconFlow::Adapters::Custom.new(nil, dir: dir).render("icon", {})
      end
    end

    it "falls back to Latin-1 when the bytes are not valid UTF-8" do
      html = render_bytes("<svg viewBox=\"0 0 1 1\"><!-- Sm\xE6l --></svg>".b)
      expect(html.encoding).to eq(Encoding::UTF_8)
      expect(html).to include("icon icon-icon")
      expect(html).to include("Smæl")
    end

    it "honours an XML encoding declaration" do
      html = render_bytes(
        "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>" \
        "<svg viewBox=\"0 0 1 1\"><!-- Sm\xE6l --></svg>".b
      )
      expect(html).to include("Smæl")
    end

    it "strips a UTF-8 BOM before the root element" do
      html = render_bytes("\xEF\xBB\xBF<svg viewBox=\"0 0 1 1\"></svg>".b)
      expect(html).not_to start_with("\uFEFF")
      expect(html).to include("data-icon-pack")
    end
  end

  Jekyll::IconFlow::ADAPTERS.each_key do |pack|
    describe pack do
      let(:site) { make_site("icon_flow" => { "custom_dir" => "custom_icons" }) }
      let(:html) do
        Jekyll::IconFlow::ADAPTERS[pack].new(site)
                                        .render(CONTRACT_ICONS.fetch(pack), "size" => "2em")
      end

      it "emits the normalized styling contract" do
        expect(html).to include("icon icon-#{CONTRACT_ICONS.fetch(pack)}")
        expect(html).to include(%(data-icon-pack="#{pack}"))
        expect(html).to include('style="width:2em;height:2em"')
        expect(html).to include('role="img"')
        expect(html).to match(/(fill|stroke)="currentColor"/)
        expect(html).not_to match(/\swidth="\d/)
      end

      it "lists its vendored icons" do
        names = Jekyll::IconFlow::ADAPTERS[pack].new(site).icon_names
        expect(names).to include(CONTRACT_ICONS.fetch(pack))
      end

      # Smoke test: every vendored SVG normalizes — a corrupt file fails
      # here, not on the first page that uses it.
      it "renders every vendored icon without error" do
        adapter = Jekyll::IconFlow::ADAPTERS[pack].new(site)
        names = adapter.icon_names
        expect(names).not_to be_empty
        names.each do |icon|
          html = adapter.render(icon, {})
          expect(html).to include('role="img"')
          expect(html).to include(%(data-icon-pack="#{pack}"))
        end
      end
    end
  end
end
