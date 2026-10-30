# frozen_string_literal: true

require "test_helper"
require "tmpdir"

# Contract test: the same normalized output shape must hold for every
# registered adapter — swap packs, keep styling (adapter-contract-testing
# pattern).
class AdapterContractTest < IconFlowTest
  CONTRACT_ICONS = {
    "lucide" => "search",
    "simple" => "github",
    "custom" => "star"
  }.freeze

  # Enumerated at load time so a corrupt vendored SVG names the icon in
  # the test failure instead of aborting a loop midway.
  PACK_ICONS = Jekyll::IconFlow::ADAPTERS.to_h do |pack, klass|
    icons = if pack == "custom"
              klass.new(nil, dir: File.expand_path("fixtures/custom_icons", __dir__)).icon_names
            else
              klass.new.icon_names
            end
    [pack, icons]
  end.freeze

  def test_base_adapter_hooks_raise_not_implemented
    adapter = Jekyll::IconFlow::Adapter.new

    assert_raises(NotImplementedError) { adapter.pack_name }
    assert_raises(NotImplementedError) { adapter.path_for("x") }
    assert_raises(NotImplementedError) { adapter.icon_names }
  end

  def test_recolors_hard_coded_colors_on_child_elements_without_changing_fill_none
    adapter = Jekyll::IconFlow::Adapters::Custom.new
    svg = '<svg viewBox="0 0 1 1"><path fill="#ff0000" stroke="blue" d="M0 0"/>' \
          '<path fill="none" stroke="url(#gradient)" d="M1 1"/></svg>'
    html = adapter.send(:normalize, svg, "star", {})

    assert_includes html, '<path fill="currentColor" stroke="currentColor"'
    assert_includes html, 'fill="none" stroke="url(#gradient)"'
  end

  # User-supplied SVGs (custom_dir, icon_flow.packs) are bytes of unknown
  # provenance — a Latin-1 download must not crash the build.
  def test_falls_back_to_latin1_when_the_bytes_are_not_valid_utf8
    html = render_bytes("<svg viewBox=\"0 0 1 1\"><!-- Sm\xE6l --></svg>".b)

    assert_equal Encoding::UTF_8, html.encoding
    assert_includes html, "icon icon-icon"
    assert_includes html, "Smæl"
  end

  def test_honours_an_xml_encoding_declaration
    html = render_bytes(
      "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>" \
      "<svg viewBox=\"0 0 1 1\"><!-- Sm\xE6l --></svg>".b
    )

    assert_includes html, "Smæl"
  end

  def test_treats_an_unresolvable_encoding_declaration_as_undeclared
    html = render_bytes(
      "<?xml version=\"1.0\" encoding=\"BOGUS-99\"?><svg viewBox=\"0 0 1 1\"></svg>".b
    )

    assert_includes html, "icon icon-icon"
    assert_includes html, "data-icon-pack"
  end

  def test_strips_a_utf8_bom_before_the_root_element
    html = render_bytes("\xEF\xBB\xBF<svg viewBox=\"0 0 1 1\"></svg>".b)

    refute html.start_with?("\uFEFF")
    assert_includes html, "data-icon-pack"
  end

  def test_merges_size_style_into_an_existing_root_style_attribute
    html = render_bytes('<svg style="color:red" viewBox="0 0 1 1"></svg>'.b)

    assert_includes html, 'style="color:red;width:1em;height:1em"'
  end

  Jekyll::IconFlow::ADAPTERS.each_key do |pack|
    define_method "test_#{pack}_emits_the_normalized_styling_contract" do
      site = make_site("icon_flow" => { "custom_dir" => "custom_icons" })
      html = Jekyll::IconFlow::ADAPTERS[pack].new(site)
                                             .render(CONTRACT_ICONS.fetch(pack), "size" => "2em")

      assert_includes html, "icon icon-#{CONTRACT_ICONS.fetch(pack)}"
      assert_includes html, %(data-icon-pack="#{pack}")
      assert_includes html, 'style="width:2em;height:2em"'
      assert_includes html, 'role="img"'
      assert_match(/(fill|stroke)="currentColor"/, html)
      refute_match(/\swidth="\d/, html)
    end

    define_method "test_#{pack}_lists_its_vendored_icons" do
      site = make_site("icon_flow" => { "custom_dir" => "custom_icons" })
      names = Jekyll::IconFlow::ADAPTERS[pack].new(site).icon_names

      refute_empty names
      assert_includes names, CONTRACT_ICONS.fetch(pack)
    end
  end

  # Smoke test: every vendored SVG normalizes — a corrupt file fails
  # here, not on the first page that uses it.
  PACK_ICONS.each do |pack, icons|
    icons.each do |icon|
      define_method "test_#{pack}_renders_#{icon}_without_error" do
        site = make_site("icon_flow" => { "custom_dir" => "custom_icons" })
        html = Jekyll::IconFlow::ADAPTERS[pack].new(site).render(icon, {})

        assert_includes html, 'role="img"'
        assert_includes html, %(data-icon-pack="#{pack}")
      end
    end
  end

  private

  def render_bytes(bytes)
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, "icon.svg"), bytes)
      Jekyll::IconFlow::Adapters::Custom.new(nil, dir: dir).render("icon", {})
    end
  end
end
