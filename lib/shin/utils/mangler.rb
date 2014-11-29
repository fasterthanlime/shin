
module Shin
  module Utils
    module Mangler
      SYM_START_REGEXP = /[A-Za-z\-_\*'\+\/\?!\$%&<>=\.\|]/
      SYM_INNER_REGEXP = /[A-Za-z\-_\*'\+\/\?!\$%&<>=\.\|#\$0-9]/

      MANGLE_REGEXP   = /[\-\*\+\/\?!\$%&<>=\.\|]/
      UNMANGLE_REGEXP = /\$[\$_a-z]/

      MANGLE_MAP = {
        '-' => '$_',
        '*' => '$m',
        '+' => '$p',
        '/' => '$v',
        '?' => '$q',
        '!' => '$e',
        '$' => '$$',
        '%' => '$c',
        '&' => '$a',
        '>' => '$g',
        '<' => '$s',
        '=' => '$l',
        '.' => '$d',
        '|' => '$i',
        "'" => '$u',
      }
      UNMANGLE_MAP = MANGLE_MAP.invert
      raise "Mangle map has overlaps (#{MANGLE_MAP.count} vs #{UNMANGLE_MAP.count})" unless MANGLE_MAP.count == UNMANGLE_MAP.count

      def mangle(id)
        id.gsub(MANGLE_REGEXP, MANGLE_MAP)
      end

      def unmangle
        id.gsub(UNMANGLE_REGEXP, UNMANGLE_MAP)
      end
    end
  end
end

