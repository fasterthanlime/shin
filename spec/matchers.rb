
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

js = Shin::JsContext.new

RSpec::Matchers.define :have_output do |expected_output|
  output = []
  code = nil

  match do |actual|
    res = Shin::Compiler.new.compile(actual)

    js.context['print'] = lambda do |_, msg|
      output << msg
    end
    code = res[:code]
    js.load(code, :inline => true)

    output.join(" ") === expected_output
  end

  failure_message do |actual|
    "expected output '#{expected_output}', got '#{output.join(" ")}', code = '#{code}'"
  end
end

