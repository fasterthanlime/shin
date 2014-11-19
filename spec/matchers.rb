
require 'shin/js_context'
require 'shin/compiler'
require 'shin/parser'
require 'shin/utils/matcher'
include Shin::Utils::Matcher

RSpec::Matchers.define :ast_match do |pattern|

  match do |actual|
    Shin::Utils::Matcher.send(:matches?, Shin::Parser.parse(actual), pattern) 
  end

  failure_message do |actual|
    "expected '#{actual}' to match AST pattern '#{pattern}'"
  end

  failure_message_when_negated do |actual|
    "expected '#{actual}' not to match AST pattern '#{pattern}'"
  end
end

cache = Shin::ModuleCache.new
js = Shin::JsContext.new
js.context['debug'] = lambda do |_, *args|
  puts "[debug] #{args.join(" ")}"
end

RSpec::Matchers.define :have_output do |expected_output|
  output = []
  code = nil

  match do |actual|
    source = nil
    macros = nil
    case actual
    when String
      source = actual
    else
      source = actual[:source]
      macros = actual[:macros]
    end

    compiler = Shin::Compiler.new(:cache => cache)
    res = compiler.compile(source, :macros => macros)

    js.providers << compiler
    js.context['print'] = lambda do |_, *args|
      output << args.join(" ")
    end
    code = res.code
    js.load(code, :inline => true)
    js.providers.delete(compiler)

    output.join(" ") === expected_output
  end

  failure_message do |actual|
    "expected output '#{expected_output}', got '#{output.join(" ")}', JS code:\n#{code}"
  end
end

