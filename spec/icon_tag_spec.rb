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

  it "supports the fleet-convention alias {% lucide_icon %}" do
    html = render_tag('lucide_icon "map-pin"')
    expect(html).to include("icon-map-pin")
    expect(html).to include('data-icon-pack="lucide"')
  end

  it "keeps styling params identical across packs" do
    html = render_tag('icon_lucide "file-text" size:1.5em class:"has-text-link"')
    expect(html).to include('style="width:1.5em;height:1.5em"')
    expect(html).to include("has-text-link")
  end

  it "resolves named sizes to relative em values" do
    { "xs" => "0.75em", "l" => "1.25em", "xxl" => "2em" }.each do |name, em|
      expect(render_tag("icon_lucide search size:#{name}")).to include("width:#{em};height:#{em}")
    end
  end

  it "defaults to size m (1em) when no size is given" do
    expect(render_tag("icon_lucide search")).to include("width:1em;height:1em")
    expect(render_tag("icon_lucide search size:m")).to include("width:1em;height:1em")
  end

  it "rejects unknown size names in strict mode" do
    site = make_site("icon_flow" => { "on_missing" => "strict" })
    expect { render_tag!("icon_lucide search size:huge", site: site) }
      .to raise_error(Jekyll::IconFlow::Error, /size/)
  end

  it "resolves context variables for name and pack" do
    html = render_tag("icon include.name pack: include.pack",
                      vars: { "include" => { "name" => "map-pin", "pack" => "lucide" } })
    expect(html).to include("icon-map-pin")
  end

  it "drops unresolved var-path params instead of passing literals" do
    html = render_tag('icon search size: include["size"]', vars: { "include" => {} })
    expect(html).to include('style="width:1em;height:1em"')
  end

  it "uses icon_flow.pack as the default for {% icon %}" do
    site = make_site("icon_flow" => { "pack" => "simple" })
    html = render_tag("icon github", site: site)
    expect(html).to include('data-icon-pack="simple"')
  end

  it "renders nothing when icon_flow.enabled is false" do
    site = make_site("icon_flow" => { "enabled" => false })
    expect(render_tag("icon_lucide search", site: site)).to eq("")
  end

  it "warns and renders empty for an unknown icon (default)" do
    site = make_site # build before stubbing — Jekyll::Site.new warns itself
    expect(Jekyll.logger).to receive(:warn).with("icon_flow:", /not found/)
    expect(render_tag("icon_lucide no-such-icon-xyz", site: site)).to eq("")
  end

  it "raises for an unknown icon when on_missing is strict" do
    site = make_site("icon_flow" => { "on_missing" => "strict" })
    expect { render_tag!("icon_lucide no-such-icon-xyz", site: site) }
      .to raise_error(Jekyll::IconFlow::Error, /not found/)
  end

  it "renders a custom pack icon from the site dir" do
    site = make_site("icon_flow" => { "custom_dir" => "custom_icons" })
    html = render_tag("icon_custom star", site: site)
    expect(html).to include('data-icon-pack="custom"')
    expect(html).to include("icon-star")
  end

  it "searches all packs for {% icon %} (custom → simple → lucide)" do
    site = make_site("icon_flow" => { "custom_dir" => "custom_icons" })
    expect(render_tag("icon star", site: site)).to include('data-icon-pack="custom"')
    expect(render_tag("icon github", site: site)).to include('data-icon-pack="simple"')
    expect(render_tag("icon search", site: site)).to include('data-icon-pack="lucide"')
  end

  it "lets the search order resolve name collisions (rss: simple before lucide)" do
    site = make_site
    expect(render_tag("icon rss", site: site)).to include('data-icon-pack="simple"')
    expect(render_tag("icon_lucide rss", site: site)).to include('data-icon-pack="lucide"')
  end

  it "honors icon_flow.search order" do
    site = make_site("icon_flow" => { "search" => ["lucide"] })
    expect(render_tag("icon search", site: site)).to include('data-icon-pack="lucide"')
    expect(render_tag("icon github", site: site)).to eq("")
  end

  it "pins {% icon %} to icon_flow.pack when configured" do
    site = make_site("icon_flow" => { "pack" => "lucide", "on_missing" => "strict" })
    expect(render_tag("icon search", site: site)).to include('data-icon-pack="lucide"')
    expect { render_tag!("icon github", site: site) }
      .to raise_error(Jekyll::IconFlow::Error, /not found/)
  end

  it "renders a named pack directory from icon_flow.packs" do
    site = make_site("icon_flow" => { "packs" => { "fa" => "fa_icons" } })
    html = render_tag("icon flag pack:fa", site: site)
    expect(html).to include('data-icon-pack="fa"')
    expect(html).to include("icon-flag")
  end

  it "includes named packs in the {% icon %} search chain" do
    site = make_site("icon_flow" => {
                       "packs" => { "fa" => "fa_icons" },
                       "search" => %w[fa lucide]
                     })
    expect(render_tag("icon flag", site: site)).to include('data-icon-pack="fa"')
    expect(render_tag("icon github", site: site)).to eq("")
  end

  it "resolves named packs through {% icon_ref %}" do
    site = make_site("icon_flow" => {
                       "packs" => { "fa" => "fa_icons" },
                       "registry" => { "banner" => "fa:flag" }
                     })
    expect(render_tag("icon_ref banner", site: site)).to include('data-icon-pack="fa"')
  end

  it "escapes styling supplied through Liquid variables" do
    html = render_tag("icon_lucide search class: page.css title: page.label",
                      vars: { "page" => { "css" => 'x" onmouseover="alert(1)',
                                          "label" => '<img src=x onerror="alert(1)">' } })
    expect(html).to include("x&quot; onmouseover=&quot;alert(1)")
    expect(html).not_to include(' onmouseover="alert(1)"')
    expect(html).to include("&lt;img src=x onerror=&quot;alert(1)&quot;&gt;")
  end

  it "rejects unsafe CSS sizes in strict mode" do
    site = make_site("icon_flow" => { "on_missing" => "strict" })
    vars = { "page" => { "size" => '1em" onload="alert(1)' } }
    expect do
      render_tag!("icon_lucide search size: page.size", site: site, vars: vars)
    end.to raise_error(Jekyll::IconFlow::Error, /size/)
  end
end
