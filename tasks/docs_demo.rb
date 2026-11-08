# frozen_string_literal: true

require "erb"
require "fileutils"
require_relative "../lib/jekyll-icon-flow"

module Jekyll
  module IconFlow
    module DocsDemo
      STEPS = 4
      VIEWPORT = "880,560"
      FRAME_MS = "1000"
      TEMPLATE = File.join(__dir__, "docs-demo.html.erb")

      module_function

      def run(root)
        write(root)
        frames(root)
        encode(root)
        puts "Wrote demo.html and icon-flow-demo captures under docs/assets"
      end

      def write(root)
        FileUtils.mkdir_p(assets_dir(root))
        File.write(File.join(assets_dir(root), "demo.html"), render_html)
      end

      def render_html
        ERB.new(File.read(TEMPLATE), trim_mode: "-").result(binding)
      end

      def frames(root, chrome: ENV["CHROME_BIN"] || default_chrome)
        abort "Chrome not found (set CHROME_BIN)" unless File.executable?(chrome)

        dir = assets_dir(root)
        page = "file://#{File.join(dir, 'demo.html')}"
        STEPS.times { |step| capture_frame(chrome, page, dir, step) }
      end

      def capture_frame(chrome, page, dir, step)
        output = File.join(dir, "frames/f#{step}.png")
        FileUtils.mkdir_p(File.dirname(output))
        system(chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars",
               "--screenshot=#{output}", "--window-size=#{VIEWPORT}",
               "#{page}?step=#{step}", out: File::NULL, err: File::NULL) ||
          abort("Chrome screenshot failed (step #{step})")
      end

      def encode(root)
        dir = assets_dir(root)
        FileUtils.cp(File.join(dir, "frames/f0.png"), File.join(dir, "icon-flow-demo.png"))
        encode_avif(dir)
        encode_webp(dir)
      end

      def encode_avif(dir)
        system("ffmpeg", "-y", "-framerate", "1", "-i", File.join(dir, "frames/f%d.png"),
               "-c:v", "libsvtav1", "-crf", "35", "-pix_fmt", "yuv420p",
               File.join(dir, "icon-flow-demo.avif"), out: File::NULL, err: File::NULL) ||
          abort("ffmpeg AVIF encode failed (requires libsvtav1)")
      end

      def encode_webp(dir)
        frames = Dir[File.join(dir, "frames/f*.png")]
        system("img2webp", "-loop", "0", "-d", FRAME_MS, *frames,
               "-o", File.join(dir, "icon-flow-demo.webp"), out: File::NULL, err: File::NULL) ||
          abort("img2webp encode failed")
      end

      def assets_dir(root)
        File.join(root, "docs/assets")
      end

      def default_chrome
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
      end

      def lucide(name, opts = {})
        Adapters::Lucide.new.render(name, opts)
      end

      def simple(name, opts = {})
        Adapters::Simple.new.render(name, opts)
      end

      def pack_examples
        examples = [
          ["icon_lucide search", lucide("search")],
          ["icon_simple github", simple("github")],
          ["icon_lucide file-text", lucide("file-text")]
        ]
        examples.map do |tag, svg|
          %(<div class="card"><span>#{svg}</span><code>{% #{tag} %}</code></div>)
        end.join
      end

      def size_examples
        %w[xs s m l xl xxl].map do |size|
          icon = lucide("check", "size" => size)
          %(#{icon}<small>#{size}</small>)
        end.join
      end

      def color_examples
        %w[#6b21a8 #0369a1 #b91c1c #15803d].map do |color|
          icon = lucide("mail")
          %(<span style="color:#{color}">#{icon} #{color}</span>)
        end.join
      end

      def icon_ref_example
        config = { "icon_flow" => { "registry" => { "download" => "lucide:arrow-down" } } }
        site = Struct.new(:config).new(config)
        markup = '{% icon_ref download size:1.5em class:"has-text-link" title:"Download" %}'
        Liquid::Template.parse(markup).render({}, registers: { site: site })
      end
    end
  end
end
