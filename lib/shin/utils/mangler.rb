
module Shin
  module Utils
    module Mangler
      ID_START_REGEXP = /[A-Za-z\-_\*'\+\/\?!\$%&<>=\.]/
      ID_INNER_REGEXP = /[A-Za-z\-_\*'\+\/\?!\$%&<>=\.#\$0-9]/

      def mangle(id)
        id.
          gsub('-', '$_').
          gsub('?', '$q').
          gsub('!', '$e').
          gsub('*', '$m').
          gsub('/', '$d').
          gsub('+', '$p').
          gsub('=', '$l').
          gsub('>', '$g').
          gsub('<', '$s').
          gsub('.', '$d').
          gsub('%', '$c').
          to_s
      end

      def unmangle
        id.
          gsub('$_', '-').
          gsub('$q', '?').
          gsub('$e', '!').
          gsub('$m', '*').
          gsub('$d', '/').
          gsub('$p', '+').
          gsub('$l', '=').
          gsub('$g', '>').
          gsub('$s', '<').
          gsub('$d', '.').
          gsub('$c', '%').
          to_s
      end
    end
  end
end

