
module Shin
  module Utils
    module GlobalCache
      def global_cache
        @@global_cache ||= Shin::ModuleCache.new
      end
    end
  end
end

