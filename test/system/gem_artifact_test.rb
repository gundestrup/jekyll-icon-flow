# frozen_string_literal: true

require "test_helper"
require "bundler"
require "fileutils"
require "rubygems/package"
require "tmpdir"

# Verifies the packaged artifact, not just lib/ — catches spec.files glob
# gaps that lib-level tests can't see. Run via `rake test:system`.
class GemArtifactTest < Minitest::Test
  GEMSPEC = File.join(PROJECT_ROOT, "jekyll-icon-flow.gemspec")

  def setup
    @tmp = Dir.mktmpdir
    @gem_path = File.join(@tmp, "jekyll-icon-flow.gem")
    Dir.chdir(PROJECT_ROOT) do
      system("gem", "build", GEMSPEC, "--output", @gem_path, exception: true)
    end
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def test_package_contents_and_metadata
    package_spec = Gem::Package.new(@gem_path).spec
    declared = Gem::Specification.load(GEMSPEC)

    assert_equal declared.version.to_s, package_spec.version.to_s
    assert_equal declared.required_ruby_version.to_s, package_spec.required_ruby_version.to_s
    %w[lib/jekyll-icon-flow.rb README.md LICENSE.txt CHANGELOG.md interface.yml
       assets/icons/lucide/search.svg assets/icons/simple/github.svg].each do |file|
      assert_includes package_spec.files, file
    end
    assert_includes package_spec.runtime_dependencies.map(&:name), "jekyll"
  end

  def test_installed_gem_renders_icon_tags
    installed = File.join(@tmp, "installed")
    Gem::Package.new(@gem_path).extract_files(installed)
    FileUtils.cp GEMSPEC, installed

    assert_path_exists File.join(installed, "lib", "jekyll-icon-flow.rb")
    assert_path_exists File.join(installed, "assets", "icons", "lucide", "search.svg")

    site_dir = File.join(@tmp, "site")
    FileUtils.mkdir_p(site_dir)
    File.write(File.join(site_dir, "_config.yml"), "plugins:\n  - jekyll-icon-flow\n")
    File.write(File.join(site_dir, "index.md"), <<~MD)
      ---
      ---
      {% icon search %} {% icon_simple github %}
    MD
    File.write(File.join(site_dir, "Gemfile"), <<~RUBY)
      source "https://rubygems.org"
      gem "jekyll"
      gem "jekyll-icon-flow", path: "#{installed}"
    RUBY

    Bundler.with_unbundled_env do
      Dir.chdir(site_dir) do
        system({ "BUNDLE_GEMFILE" => File.join(site_dir, "Gemfile") },
               "bundle", "install", "--quiet", exception: true)
        system("bundle", "exec", "jekyll", "build", "--quiet", exception: true)
      end
    end

    html = File.read(File.join(site_dir, "_site", "index.html"))

    assert_includes html, 'data-icon-pack="lucide"'
    assert_includes html, 'data-icon-pack="simple"'
    assert_includes html, "icon-search"
  end
end
