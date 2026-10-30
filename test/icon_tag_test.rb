# frozen_string_literal: true

require "test_helper"

class IconTagTest < IconFlowTest
  def test_renders_a_lucide_icon_with_the_normalized_contract
    html = render_tag("icon_lucide search")

    assert_includes html, 'class="lucide lucide-search icon icon-search"'
    assert_includes html, 'data-icon-pack="lucide"'
    assert_includes html, 'style="width:1em;height:1em"'
    assert_includes html, 'stroke="currentColor"'
    refute_includes html, 'width="24"'
    assert_includes html, 'role="img"'
  end

  def test_normalizes_simple_icons_to_fill_current_color
    html = render_tag("icon_simple github")

    assert_includes html, 'data-icon-pack="simple"'
    assert_includes html, 'fill="currentColor"'
    assert_includes html, "icon icon-github"
  end

  def test_supports_the_fleet_convention_alias_lucide_icon
    html = render_tag('lucide_icon "map-pin"')

    assert_includes html, "icon-map-pin"
    assert_includes html, 'data-icon-pack="lucide"'
  end

  def test_keeps_styling_params_identical_across_packs
    html = render_tag('icon_lucide "file-text" size:1.5em class:"has-text-link"')

    assert_includes html, 'style="width:1.5em;height:1.5em"'
    assert_includes html, "has-text-link"
  end

  def test_resolves_named_sizes_to_relative_em_values
    { "xs" => "0.75em", "l" => "1.25em", "xxl" => "2em" }.each do |name, em|
      assert_includes render_tag("icon_lucide search size:#{name}"), "width:#{em};height:#{em}"
    end
  end

  def test_defaults_to_size_m_1em_when_no_size_is_given
    assert_includes render_tag("icon_lucide search"), "width:1em;height:1em"
    assert_includes render_tag("icon_lucide search size:m"), "width:1em;height:1em"
  end

  def test_rejects_unknown_size_names_in_strict_mode
    site = make_site("icon_flow" => { "on_missing" => "strict" })
    error = assert_raises(Jekyll::IconFlow::Error) do
      render_tag!("icon_lucide search size:huge", site: site)
    end
    assert_match(/size/, error.message)
  end

  def test_resolves_context_variables_for_name_and_pack
    html = render_tag("icon include.name pack: include.pack",
                      vars: { "include" => { "name" => "map-pin", "pack" => "lucide" } })

    assert_includes html, "icon-map-pin"
  end

  def test_drops_unresolved_var_path_params_instead_of_passing_literals
    html = render_tag('icon search size: include["size"]', vars: { "include" => {} })

    assert_includes html, 'style="width:1em;height:1em"'
  end

  def test_uses_icon_flow_pack_as_the_default_for_icon
    site = make_site("icon_flow" => { "pack" => "simple" })
    html = render_tag("icon github", site: site)

    assert_includes html, 'data-icon-pack="simple"'
  end

  def test_renders_nothing_when_icon_flow_enabled_is_false
    site = make_site("icon_flow" => { "enabled" => false })

    assert_equal "", render_tag("icon_lucide search", site: site)
  end

  def test_warns_and_renders_empty_for_an_unknown_icon_default
    site = make_site # build before stubbing — Jekyll::Site.new warns itself
    warnings = []

    Jekyll.logger.stub(:warn, ->(channel, message) { warnings << [channel, message] }) do
      assert_equal "", render_tag("icon_lucide no-such-icon-xyz", site: site)
    end
    assert_equal 1, warnings.size
    channel, message = warnings.first

    assert_equal "icon_flow:", channel
    assert_match(/not found/, message)
  end

  def test_raises_for_an_unknown_pack_in_strict_mode
    site = make_site("icon_flow" => { "on_missing" => "strict" })
    error = assert_raises(Jekyll::IconFlow::Error) do
      render_tag!("icon search pack:nosuchpack", site: site)
    end

    assert_match(/unknown icon pack 'nosuchpack'/, error.message)
  end

  def test_raises_for_an_unknown_icon_when_on_missing_is_strict
    site = make_site("icon_flow" => { "on_missing" => "strict" })
    error = assert_raises(Jekyll::IconFlow::Error) do
      render_tag!("icon_lucide no-such-icon-xyz", site: site)
    end
    assert_match(/not found/, error.message)
  end

  def test_renders_a_custom_pack_icon_from_the_site_dir
    site = make_site("icon_flow" => { "custom_dir" => "custom_icons" })
    html = render_tag("icon_custom star", site: site)

    assert_includes html, 'data-icon-pack="custom"'
    assert_includes html, "icon-star"
  end

  def test_searches_all_packs_for_icon_custom_simple_lucide
    site = make_site("icon_flow" => { "custom_dir" => "custom_icons" })

    assert_includes render_tag("icon star", site: site), 'data-icon-pack="custom"'
    assert_includes render_tag("icon github", site: site), 'data-icon-pack="simple"'
    assert_includes render_tag("icon search", site: site), 'data-icon-pack="lucide"'
  end

  def test_lets_the_search_order_resolve_name_collisions_rss_simple_before_lucide
    site = make_site

    assert_includes render_tag("icon rss", site: site), 'data-icon-pack="simple"'
    assert_includes render_tag("icon_lucide rss", site: site), 'data-icon-pack="lucide"'
  end

  def test_honors_icon_flow_search_order
    site = make_site("icon_flow" => { "search" => ["lucide"] })

    assert_includes render_tag("icon search", site: site), 'data-icon-pack="lucide"'
    assert_equal "", render_tag("icon github", site: site)
  end

  def test_pins_icon_to_icon_flow_pack_when_configured
    site = make_site("icon_flow" => { "pack" => "lucide", "on_missing" => "strict" })

    assert_includes render_tag("icon search", site: site), 'data-icon-pack="lucide"'
    error = assert_raises(Jekyll::IconFlow::Error) do
      render_tag!("icon github", site: site)
    end
    assert_match(/not found/, error.message)
  end

  def test_renders_a_named_pack_directory_from_icon_flow_packs
    site = make_site("icon_flow" => { "packs" => { "fa" => "fa_icons" } })
    html = render_tag("icon flag pack:fa", site: site)

    assert_includes html, 'data-icon-pack="fa"'
    assert_includes html, "icon-flag"
  end

  def test_includes_named_packs_in_the_icon_search_chain
    site = make_site("icon_flow" => {
                       "packs" => { "fa" => "fa_icons" },
                       "search" => %w[fa lucide]
                     })

    assert_includes render_tag("icon flag", site: site), 'data-icon-pack="fa"'
    assert_equal "", render_tag("icon github", site: site)
  end

  def test_resolves_named_packs_through_icon_ref
    site = make_site("icon_flow" => {
                       "packs" => { "fa" => "fa_icons" },
                       "registry" => { "banner" => "fa:flag" }
                     })

    assert_includes render_tag("icon_ref banner", site: site), 'data-icon-pack="fa"'
  end

  def test_escapes_styling_supplied_through_liquid_variables
    html = render_tag("icon_lucide search class: page.css title: page.label",
                      vars: { "page" => { "css" => 'x" onmouseover="alert(1)',
                                          "label" => '<img src=x onerror="alert(1)">' } })

    assert_includes html, "x&quot; onmouseover=&quot;alert(1)"
    refute_includes html, ' onmouseover="alert(1)"'
    assert_includes html, "&lt;img src=x onerror=&quot;alert(1)&quot;&gt;"
  end

  def test_rejects_unsafe_css_sizes_in_strict_mode
    site = make_site("icon_flow" => { "on_missing" => "strict" })
    vars = { "page" => { "size" => '1em" onload="alert(1)' } }
    error = assert_raises(Jekyll::IconFlow::Error) do
      render_tag!("icon_lucide search size: page.size", site: site, vars: vars)
    end
    assert_match(/size/, error.message)
  end
end
