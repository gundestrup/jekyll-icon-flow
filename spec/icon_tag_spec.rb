# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jekyll::IconFlow::IconTag do
  it "renders a lucide icon with the normalized contract" do
    html = render_tag("icon_lucide search")
    expect(html).to include('class="lucide lucide-search icon icon-search"')
    expect(html).to include('data-icon-pack="lucide"')
    expect(html).to include('style="width:1em;height:1em"')
    expect(html).to include('stroke="currentColor"')
    expect(html).not_to include('width="24"')
    expect(html).to include('role="img"')
  end

  it "normalizes simple-icons to fill=currentColor" do
    html = render_tag("icon_simple github")
    expect(html).to include('data-icon-pack="simple"')
    expect(html).to include('fill="currentColor"')
    expect(html).to include("icon icon-github")
  end

  it "keeps styling params identical across packs" do
    lucide = render_tag('icon_lucide "file-text" size:1.5em class:"has-text-link"')
    expect(lucide).to include('style="width:1.5em;height:1.5em"')
    expect(lucide).to include("has-text-link")
  end

  it "resolves context variables for name and pack" do
    html = render_tag("icon include.name pack: include.pack",
                      vars: { "include" => { "name" => "map-pin", "pack" => "lucide" } })
    expect(html).to include("icon-map-pin")
  end

  it "uses icon_flow.pack as the default for {% icon %}" do
    site = FakeSite.new({ "icon_flow" => { "pack" => "simple" } }, Dir.pwd)
    html = render_tag("icon github", site: site)
    expect(html).to include('data-icon-pack="simple"')
  end

  it "renders nothing when icon_flow.enabled is false" do
    site = FakeSite.new({ "icon_flow" => { "enabled" => false } }, Dir.pwd)
    expect(render_tag("icon_lucide search", site: site)).to eq("")
  end

  it "raises for an unknown icon name" do
    expect { render_tag!("icon_lucide no-such-icon-xyz") }
      .to raise_error(Jekyll::IconFlow::Error, /not found/)
  end

  it "renders a custom pack icon from the site dir" do
    site = FakeSite.new({ "icon_flow" => { "custom_dir" => "fixtures/custom_icons" } },
                        File.expand_path(".", __dir__))
    html = render_tag("icon_custom star", site: site)
    expect(html).to include('data-icon-pack="custom"')
    expect(html).to include("icon-star")
  end
end
