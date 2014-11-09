
require 'treetop'

module Shin
  class Parser

    def initialize
      # not much to do.
    end

    def parse(data)
      tree = parser.parse(data)
     
      # If the AST is nil then there was an error during parsing
      # we need to report a simple error message to help the user
      if(tree.nil?)
        raise Exception, "Parse error at offset: #{parser.index}"
      end

      clean_tree(tree)
      
      return tree
    end

    private

    def parser
      unless @parser
        base_path = File.expand_path(File.dirname(__FILE__))
        require File.join(base_path, 'node_extensions.rb')
        Treetop.load(File.join(base_path, 'shin.treetop'))
        @parser = ShinParser.new
      end

      @parser
    end

    def clean_tree(root_node)
      return if(root_node.elements.nil?)
      root_node.elements.delete_if { |node| node.instance_of? Treetop::Runtime::SyntaxNode }
      root_node.elements.each { |node| clean_tree(node) }
    end

  end
end
