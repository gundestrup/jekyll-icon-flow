# frozen_string_literal: true

module Jekyll
  module IconFlow
    # {% icon_ref <key> %} — semantic icon names resolved through the
    # icon_flow.registry config map (the central-registry pattern):
    # call sites name intent ("download", "delete"), the map picks the
    # library icon. Swapping packs means editing one map, not grepping
    # templates.
    #
    #   icon_flow:
    #     registry:
    #       download: lucide:arrow-down
    #       github: simple:github
    #       danger: lucide:triangle-alert:has-text-danger   # 3rd field = class
    #
    #   {% icon_ref download %}
    #   {% icon_ref danger size:1.5em %}
    class IconRefTag < IconTag
      def render(context)
        site = context.registers[:site]
        return "" if site&.config&.dig("icon_flow", "enabled") == false

        render_entry(context, site)
      rescue Error => e
        missing!(site, e)
      end

      private

      def render_entry(context, site)
        key, params = name_and_params(context)
        pack, name, extra_class = registry_entry(site, key)
        params["class"] = [extra_class, params["class"]].compact.join(" ").strip
        adapter_instance(site, pack).render(name, params)
      end

      def registry_entry(site, key)
        entry = site&.config&.dig("icon_flow", "registry", key)
        raise Error, "no icon_flow.registry entry for '#{key}'" unless entry

        entry.to_s.split(":", 3)
      end
    end
  end
end
