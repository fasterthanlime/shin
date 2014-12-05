
require 'therubyracer'
require 'oj'
require 'pathname'
require 'fileutils'
require 'set'

module Shin
  class JsContext

    DEBUG = !!ENV['JSCONTEXT_DEBUG']

    attr_reader :file_provider
    attr_reader :providers

    def initialize
      @context = V8::Context.new
      @seed = 0

      @file_provider = FileJsProvider.new
      @file_provider.sourcepath << File.expand_path("../js", __FILE__)
      @providers = [@file_provider]
      @loaded = Set.new

      @context.eval %Q{
        this.$kir = {
          modules: {},

          define: function (name, deps, factory) {
            return $kir.modules[name] = {
              deps: deps,
              factory: factory,
              exports: {}
            };
          }
        }
      }
    end

    def context
      @context
    end

    def eval(source)
      @context.eval(source)
    end

    def loaded?(spec_name)
      @loaded.include?(spec_name)
    end

    def unload!(spec_name)
      return unless loaded?(spec_name)
      debug "Unloading #{spec_name}"
      @loaded.delete(spec_name)
      @context.eval("delete $kir.modules[#{escape(spec_name)}]")

      mods = @context.eval("$kir.modules")
      mods.each do |dep, mod|
        unload!(dep) if mod['deps'].include?(spec_name)
      end

    end

    def fresh_seed
      @seed += 1
    end

    def load(spec_input, inline: false)
      spec = if inline
        parse_spec("anon_#{fresh_seed}")
      else
        parse_spec(spec_input)
      end

      if spec[:text?]
        text_content = File.read(resource_path(spec[:name]))
        @context.eval %Q{
          $kir.define(#{escape(spec[:name])}, [], null).exports = #{escape(text_content)};
        }
        return
      end

      @loaded << spec[:name]

      # use globals so we can use V8::Context.load
      # and retain stack trace information.
      # the alternative is to eval the code, but
      # it makes debugging a lot harder.
      
      @context.eval %Q{
        this.$define_called = false;
        this.define = function (a, b, c) {
          $define_called = true; 
          if (typeof a === 'function') {
            $kir.define(#{escape(spec[:name])}, [], a);
          } else if (typeof a === 'string') {
            $kir.define(a, b, c);
          } else {
            $kir.define(#{escape(spec[:name])}, a, b);
          }
        }
        this.define.amd = true;
      }

      if inline
        debug "Loading #{spec[:name]} inline:\n\n#{spec_input}\n\n"
        @context.eval(spec_input, spec[:name])
      else
        done = false
        name = spec[:name] + ".js"
        @providers.each do |provider|
          res = provider.provide_js_module(name)
          case res
          when nil
            next
          when Pathname
            debug "Loading #{name} from pathname -> #{res}"
            @context.load(res.to_s)
            done = true
          else
            debug "Loading #{name} from memory"
            if hardcore_debug?
              path = ".hardcore-debug/#{spec[:name]}.js"
              FileUtils.mkdir_p(File.dirname(path))
              File.open(path, 'w') { |f| f.write(res) }
            else
              debug "(use JSCONTEXT_DEBUG=2 to dump in .hardcore-debug/)"
            end

            @context.eval(res, spec[:name])
            done = true
          end
        end
        throw "JS file not found: #{spec[:name]}" unless done
      end

      mod = @context.eval %Q{
        var name = #{escape(spec[:name])};

        if (!$define_called) {
          $kir.define(name, [], null);
        }

        delete this.$define_called;
        delete this.define;
        $kir.modules[name];
      }

      if mod[:factory].nil?
        debug "#{spec[:name]} doesn't look AMD-ready."

        # we have no factory to run.
        return
      end

      js = []
      js << "var deps = ["

      uses_exports = false

      mod[:deps].each do |dep|
        dep_spec = parse_spec(dep)
        if dep_spec[:name] == 'exports'
          uses_exports = true
          js << "$kir.modules[#{escape(spec[:name])}].exports, "
        elsif dep_spec[:name] == 'require'
          # workaround for hamt
          js << "null, "
        else
          unless loaded?(dep_spec[:name])
            load(dep_spec[:input])
          end
          js << "$kir.modules[#{escape(dep_spec[:name])}].exports, "
        end
      end
      js << "];"

      js << "var result = $kir.modules[#{escape(spec[:name])}].factory.apply(null, deps);"

      # not requesting 'exports' and just returning an object
      # is valid AMD apparently. It won't work with circular 
      # references but whatever.
      unless uses_exports
        js << "$kir.modules[#{escape(spec[:name])}].exports = result;"
      end

      # actually call the factory!
      @context.eval js.join("\n")

    end

    def resource_path(name)
      File.expand_path("../js/#{name}", __FILE__)
    end

    def escape(input)
      Oj.dump(input)
    end

    def set(key, val)
      @context[key] = val
    end

    def context
      @context
    end

    def parse_spec(spec_input)
      _, text, _, name = /^(text!)?(\.\/)?(.*)$/.match(spec_input).to_a
      {
        :input => spec_input,
        :name => name,
        :text => !!text
      }
    end

    private

    def debug(*args)
      puts("[JS_CONTEXT] #{args.join(" ")}") if DEBUG
    end

    def hardcore_debug?
      ENV['JSCONTEXT_DEBUG'] == '2'
    end

  end

  class FileJsProvider
    attr_reader :sourcepath

    def initialize(sourcepath = [])
      @sourcepath = sourcepath
    end

    def provide_js_module(name)
      @sourcepath.each do |sp|
        path = Pathname.new("#{sp}/#{name}")
        return path if path.exist?
      end
      nil
    end
  end
end

