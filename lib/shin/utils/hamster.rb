
require 'hamster/deque'

module Shin
  module Utils
    module Hamster
      def walk_deque(deq)
        c = deq
        until c.empty?
          e = c.first
          c = c.shift
          yield e
        end
      end
    end
  end
end

