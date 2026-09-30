# frozen_string_literal: true

module Jekyll
  module IconFlow
    # Reads an SVG file as UTF-8 text. Custom and named-pack SVGs are
    # user-supplied bytes of unknown provenance: honour an XML encoding
    # declaration when present, keep UTF-8 when the bytes validate, and
    # fall back to Latin-1 — so a stray-encoded icon degrades instead of
    # breaking the build with an ArgumentError deep in normalize.
    module SvgReader
      module_function

      def read(path)
        bytes = File.binread(path)
        bytes.force_encoding(declared_encoding(bytes) || Encoding::UTF_8)
        bytes.force_encoding(Encoding::ISO_8859_1) unless bytes.valid_encoding?
        bytes.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
             .delete_prefix("\uFEFF")
      end

      def declared_encoding(bytes)
        name = bytes[/\A\s*<\?xml[^?]*\bencoding\s*=\s*["']([^"']+)/i, 1]
        name && Encoding.find(name)
      rescue ArgumentError
        nil
      end
    end
  end
end
