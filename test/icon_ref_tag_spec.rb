# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jekyll::IconFlow::IconRefTag do
  let(:site) do
    make_site("icon_flow" => { "registry" => {
                "download" => "lucide:arrow-down",
                "github" => "simple:github",
                "danger" => "lucide:triangle-alert:has-text-danger"
              } })
  end

  it "resolves a registry key to pack + icon" do
    html = render_tag("icon_ref download", site: site)
    expect(html).to include('data-icon-pack="lucide"')
    expect(html).to include("icon-arrow-down")
  end

  it "can point at a different pack per key" do
    html = render_tag("icon_ref github", site: site)
    expect(html).to include('data-icon-pack="simple"')
  end

  it "merges the registry's third field into class" do
    html = render_tag("icon_ref danger", site: site)
    expect(html).to include("has-text-danger")
    expect(html).to include("icon-triangle-alert")
  end

  it "passes styling params through" do
    html = render_tag("icon_ref download size:2em", site: site)
    expect(html).to include('style="width:2em;height:2em"')
  end

  it "warns and renders empty for a missing registry key" do
    site # build before stubbing — Jekyll::Site.new warns itself
    expect(Jekyll.logger).to receive(:warn).with("icon_flow:", /no icon_flow\.registry entry/)
    expect(render_tag("icon_ref not-there", site: site)).to eq("")
  end

  it "raises for a missing key when on_missing is strict" do
    strict = make_site("icon_flow" => { "on_missing" => "strict",
                                        "registry" => { "x" => "lucide:search" } })
    expect { render_tag!("icon_ref missing", site: strict) }
      .to raise_error(Jekyll::IconFlow::Error, /registry/)
  end
end
