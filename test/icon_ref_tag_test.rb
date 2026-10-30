# frozen_string_literal: true

require "test_helper"

class IconRefTagTest < IconFlowTest
  def site
    @site ||= make_site("icon_flow" => { "registry" => {
                          "download" => "lucide:arrow-down",
                          "github" => "simple:github",
                          "danger" => "lucide:triangle-alert:has-text-danger"
                        } })
  end

  def test_resolves_a_registry_key_to_pack_and_icon
    html = render_tag("icon_ref download", site: site)

    assert_includes html, 'data-icon-pack="lucide"'
    assert_includes html, "icon-arrow-down"
  end

  def test_can_point_at_a_different_pack_per_key
    html = render_tag("icon_ref github", site: site)

    assert_includes html, 'data-icon-pack="simple"'
  end

  def test_merges_the_registrys_third_field_into_class
    html = render_tag("icon_ref danger", site: site)

    assert_includes html, "has-text-danger"
    assert_includes html, "icon-triangle-alert"
  end

  def test_passes_styling_params_through
    html = render_tag("icon_ref download size:2em", site: site)

    assert_includes html, 'style="width:2em;height:2em"'
  end

  def test_warns_and_renders_empty_for_a_missing_registry_key
    site # build before stubbing — Jekyll::Site.new warns itself
    warnings = []

    Jekyll.logger.stub(:warn, ->(channel, message) { warnings << [channel, message] }) do
      assert_equal "", render_tag("icon_ref not-there", site: site)
    end
    assert_equal 1, warnings.size
    channel, message = warnings.first

    assert_equal "icon_flow:", channel
    assert_match(/no icon_flow\.registry entry/, message)
  end

  def test_raises_for_a_missing_key_when_on_missing_is_strict
    strict = make_site("icon_flow" => { "on_missing" => "strict",
                                        "registry" => { "x" => "lucide:search" } })
    error = assert_raises(Jekyll::IconFlow::Error) do
      render_tag!("icon_ref missing", site: strict)
    end
    assert_match(/registry/, error.message)
  end
end
