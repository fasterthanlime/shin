
require 'shin/utils'

module Shin
  class NsParser
    include Shin::Utils::Matcher

    attr_reader :mod
    @@seed = 0

    def initialize(mod)
      @mod = mod
    end

    def parse
      return if mod.ns

      nsdef = mod.ast[0]
      ns = nil
      if nsdef && nsdef.list?
        matches?(nsdef.inner, "ns :sym :expr*") do |_, name, specs|
          # get rid of nsdef (don't translate it)
          mod.ast = mod.ast.drop(1)

          ns = name.value
          specs.each do |spec|
            matches?(spec.inner, ":kw []") do |type, vec|
              list = vec.inner
              until list.empty?
                aka = name = list.first
                throw "invalid spec, expected sym got #{name}" unless name.sym?
                list = list.drop(1)
                if !list.empty? && list.first.kw?('as')
                  list = list.drop(1)
                  aka = list.first
                  list = list.drop(1)
                end

                mod.requires << {
                  :type => type.value,
                  :name => name.value,
                  :aka  => aka.value,
                }
              end
            end or throw "invalid spec #{spec}"
          end
        end
      end

      ns ||= "anonymous#{fresh}"
      mod.ns = ns

      if mod.ns != 'shin.core'
        mod.requires << {
          :type => 'use',
          :name => 'shin.core',
          :aka => 'shin'
        }
      end
    end

    def fresh
      @@seed += 1
    end

  end
end

