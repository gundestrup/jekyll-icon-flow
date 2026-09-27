# frozen_string_literal: true

require "spec_helper"

# Contract test: the same normalized output shape must hold for every
# registered adapter — swap packs, keep styling (adapter-contract-testing
# pattern).
CONTRACT_ICONS = {
  "lucide" => "search",
  "simple" => "github",
  "custom" => "star"
}.freeze

RSpec.describe "adapter output contract" do
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
    end
  end
end
