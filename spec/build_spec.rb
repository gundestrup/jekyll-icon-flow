# frozen_string_literal: true

require "spec_helper"

# Full-build integration: a real site whose pages use the tags, built
# through Jekyll::Site#process — not just tag rendering in isolation.
RSpec.describe "site build integration" do
  it "renders all tag forms into the generated page" do
    files = jekyll_files do
      file "_layouts/default.html" do
        contents "<html><body>{{ content }}</body></html>"
      end
      file "assets/icons/custom/star.svg" do
        contents '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">' \
                 "<path d='M0 0h24v24H0z'/></svg>"
      end
      file "index.md" do
        frontmatter("layout" => "default", "title" => "Home")
        contents "{% icon search %} {% icon_simple github %} " \
                 "{% icon_custom star %} {% icon_ref download %}"
      end
    end

    jekyll_build(
      config: {
        "icon_flow" => {
          "custom_dir" => "assets/icons/custom",
          "registry" => { "download" => "lucide:arrow-down" }
        }
      },
      files: files
    ) do |site|
      html = site.pages.find { |p| p.url == "/" }.output
      expect(html).to include('data-icon-pack="lucide"')
      expect(html).to include('data-icon-pack="simple"')
      expect(html).to include('data-icon-pack="custom"')
      expect(html).to include("icon-arrow-down")
    end
  end

  it "survives a missing icon in warn mode without failing the build" do
    files = jekyll_files do
      file "_layouts/default.html" do
        contents "<html><body>{{ content }}</body></html>"
      end
      file "index.md" do
        frontmatter("layout" => "default")
        contents "before {% icon no-such-icon-xyz %} after"
      end
    end

    jekyll_build(files: files) do |site|
      html = site.pages.find { |p| p.url == "/" }.output
      expect(html).to include("before")
      expect(html).to include("after")
    end
  end
end
