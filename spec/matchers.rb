
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

