
require 'set'

module Shin
  module Utils
    module Mangler
      SYM_START_REGEXP = /[A-Za-z\-_\*'\+\/\?!\$%&<>=\.\|]/
      SYM_INNER_REGEXP = /[A-Za-z\-_\*'\+\/\?!\$%&<>=\.\|#\$0-9]/

      MANGLE_REGEXP   = /[\-\*\+\/\?!\$%&<>=\.\|']/
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
        ""  => '$z'
      }
      UNMANGLE_MAP = MANGLE_MAP.invert
      raise "Mangle map has overlaps (#{MANGLE_MAP.length} vs #{UNMANGLE_MAP.length})" unless MANGLE_MAP.length == UNMANGLE_MAP.length

      def mangle(id)
        if reserved?(id)
          "$z#{id}"
        else
          id.gsub(MANGLE_REGEXP, MANGLE_MAP)
        end
      end

      def unmangle
        id.gsub(UNMANGLE_REGEXP, UNMANGLE_MAP)
      end

      # 'arguments' and 'eval' are reserved keywords
      # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Lexical_grammar#Keywords
      RESERVED_KEYWORDS = Set.new(%w(arguments eval) +
                                  %w(break extends switch) +
                                  %w(case finally this) +
                                  %w(class for throw) +
                                  %w(catch function try) +
                                  %w(const if typeof) +
                                  %w(continue import var) +
                                  %w(debugger in void) +
                                  %w(default instanceof while) +
                                  %w(delete let with) +
                                  %w(do new yield) +
                                  %w(else return) +
                                  %w(export super) +
                                  %w(enum await) +
                                  %w(implements static public) +
                                  %w(package interface) +
                                  %w(protected private))

      def reserved?(name)
        RESERVED_KEYWORDS.include?(name)
      end
    end
  end
end

