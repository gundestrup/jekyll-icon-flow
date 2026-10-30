# frozen_string_literal: true

require "test_helper"

# Full-build integration: a real site whose pages use the tags, built
# through Jekyll::Site#process — not just tag rendering in isolation.
class SiteBuildTest < IconFlowTest
  def test_renders_all_tag_forms_into_the_generated_page
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

      assert_includes html, 'data-icon-pack="lucide"'
      assert_includes html, 'data-icon-pack="simple"'
      assert_includes html, 'data-icon-pack="custom"'
      assert_includes html, "icon-arrow-down"
    end
  end

  def test_fails_a_real_build_for_a_missing_icon_in_strict_mode
    files = jekyll_files do
      file "index.md" do
        frontmatter("title" => "Home")
        contents "{% icon no-such-icon-xyz %}"
      end
    end

    error = assert_raises(JekyllTestHarness::SiteBuildError) do
      jekyll_build(config: { "icon_flow" => { "on_missing" => "strict" } }, files: files) do |_site|
        nil
      end
    end
    assert_match(/not found/, error.message)
  end

  def test_survives_a_missing_icon_in_warn_mode_without_failing_the_build
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

      assert_includes html, "before"
      assert_includes html, "after"
    end
  end
end
