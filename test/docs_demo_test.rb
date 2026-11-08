# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require_relative "../tasks/docs_demo"

class DocsDemoTest < Minitest::Test
  DEMO = Jekyll::IconFlow::DocsDemo

  def test_html_uses_adapter_and_liquid_output
    html = DEMO.render_html

    assert_includes html, 'data-icon-pack="lucide"'
    assert_includes html, 'data-icon-pack="simple"'
    assert_includes html, 'class="lucide lucide-search icon icon-search"'
    assert_includes html, "<title>Download</title>"
    assert_includes html, 'style="width:1.5em;height:1.5em"'
  end

  def test_write_creates_demo_page_under_docs_assets
    Dir.mktmpdir do |root|
      DEMO.write(root)

      html = File.read(File.join(root, "docs/assets/demo.html"))

      assert_includes html, 'data-icon-pack="lucide"'
    end
  end

  def test_demo_generator_is_not_in_the_published_gem
    spec = Gem::Specification.load(File.expand_path("../jekyll-icon-flow.gemspec", __dir__))

    refute_includes spec.files, "tasks/docs_demo.rb"
    refute_includes spec.files, "tasks/docs-demo.html.erb"
    refute(spec.files.any? { |file| file.start_with?("docs/assets/") })
    assert_includes spec.files, "assets/icons/lucide/PACK.yml"
  end
end
