
require 'set'

RSpec.describe "Language", "mangling" do
  describe "reserved words are mangled" do
    forbidden_words = []

    # `arguments` and `eval` are forbidden by Strict mode
    forbidden_words.concat %w(arguments eval)

    # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Lexical_grammar#Keywords
    forbidden_words.concat %w(break extends switch)
    forbidden_words.concat %w(case finally this)
    forbidden_words.concat %w(class for throw)
    forbidden_words.concat %w(catch function try)
    forbidden_words.concat %w(const if typeof)
    forbidden_words.concat %w(continue import var)
    forbidden_words.concat %w(debugger in void)
    forbidden_words.concat %w(default instanceof while)
    forbidden_words.concat %w(delete let with)
    forbidden_words.concat %w(do new yield)
    forbidden_words.concat %w(else return)
    forbidden_words.concat %w(export super)
    forbidden_words.concat %w(enum await)
    forbidden_words.concat %w(implements static public)
    forbidden_words.concat %w(package interface)
    forbidden_words.concat %w(protected private)

    # finally let's throw in a non-reserved word to see
    # if it gets mangled anyway.
    forbidden_words.concat %w(normal)

    keys = forbidden_words
    values = keys.map { |x| %Q{"#{x}"} }
    pairs = keys.zip(values)

    it "in function arguments" do
      expect(%Q{
               ((fn foo [#{keys.join(" ")}]
                  #{keys.map {|x| "(print #{x})"}.join("\n")})
                #{values.join(" ")})
             }).to have_output(keys)
    end

    it "in let" do
      expect(%Q{
               (let [#{pairs.flatten(1).join(" ")}]
                  #{keys.map {|x| "(print #{x})"}.join("\n")})
             }).to have_output(keys)
    end

    it "in deftype fields" do
      expect(%Q{
               (deftype Foo [#{keys.join(" ")}]
                 Object
                 (test [foo]
                    #{keys.map {|x| "(print #{x})"}.join("\n")}))
               (let [foo (Foo. #{values.join(" ")})] (.test foo))
             }).to have_output(keys)
    end

    it "in deftype naked method arguments" do
      expect(%Q{
               (deftype Foo []
                 Object
                 (test [_ #{keys.join(" ")}]
                    #{keys.map {|x| "(print #{x})"}.join("\n")}))
               (let [foo (Foo.)]
                 (.test foo #{values.join(" ")}))
             }).to have_output(keys)
    end

    it "in deftype protocol method arguments" do
      expect(%Q{
               (defprotocol IFear
                 (-fear [_ #{keys.join(" ")}]))
               (deftype Foo []
                 IFear
                 (-fear [_ #{keys.join(" ")}]
                    #{keys.map {|x| "(print #{x})"}.join("\n")}))
               (let [foo (Foo.)]
                 (-fear foo #{values.join(" ")}))
             }).to have_output(keys)
    end

    it "in declare" do
      expect(%Q{
          #{keys.map {|x| "(declare #{x})"}.join("\n")}
          #{keys.map {|x| "(if (== \"undefined\" (*js-uop typeof #{x})) nil (print \"#{x}\"))"}.join("\n")}
      }).to have_output(keys)
    end

    it "in def" do
      expect(%Q{
          #{keys.map {|x| "(def #{x} \"#{x}\")"}.join("\n")}
          #{keys.map {|x| "(print #{x})"}.join("\n")}
      }).to have_output(keys)
    end

    it "in defn" do
      # using apply because some will conflict with special forms
      expect(%Q{
          #{keys.map {|x| "(defn #{x} [] \"#{x}\")"}.join("\n")}
          #{keys.map {|x| "(print (apply #{x}))"}.join("\n")}
      }).to have_output(keys)
    end

    it "in defmacro" do
      expect(
        :source => %Q{
          #{keys.map {|x| "(#{x})"}.join("\n")}
        },
        :macros => %Q{
          #{keys.map {|x| "(defmacro #{x} [] `(print \"#{x}\"))"}.join("\n")}
        }
      ).to have_output(keys)
    end
  end

  describe "custom access" do
    it "js-arguments provides access" do
      expect(%Q{
           (let [f (fn [] (print (aget js-arguments 0)))]
             (f "hello"))
             }).to have_output(%w(hello))
    end
  end
end
