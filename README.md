
[![Build Status](https://travis-ci.org/memoways/shin.svg?branch=master)](https://travis-ci.org/memoways/shin)

# shin

Shin is a very immature Clojure subset that compiles to JavaScript thanks
to Ruby and V8.

It's heavily inspired by:

  - [ClojureScript][cljs]
  - The [ki language][ki]

## Rationale

ClojureScript is great, but, for the time being, the tooling is [a bit
heavy-handed][shameless-plug], slow at times, and definitely tied to the JVM.

Why write Shin in Ruby? Ruby, while problematic in many regards and anything
but "small", is a language most of the Memoways team is comfortable with. It
has a rich library ecosystem that allows one to tackle most problems quickly.

Plus, MRI start-up times are much smaller than usual JVM start-up times.
(At this time, no attempt has been made to run Shin under Rubinius, JRuby,
or any other Ruby implementation.)

## Design philosophy

Shin generates relatively naive JavaScript code. At the time of this writing,
no attempt is made a optimizing anything. Rather, the compiler is designed to
generate correct and readable code, quickly.

## Bird's eye view

  - `compiler.rb` - drives the whole thing
  - `parser.rb` - text to `Shin::AST` representation
  - `ns_parser.rb` - recognizes `ns` form, populates `requires` and
  generate anonynmous ns name if lack of ns form.
  - `mutator.rb` - expands macros, potential for an optimizer there
  - `translator.rb` - translates `Shin::AST` to `Shin::JST`, which is
  [Mozilla Parser API][moz-parser-api] in disguise.
  - `generator.rb` - generates actual JavaScript from the JST, via
  [escodegen][].

## Parser

Tried out [treetop][] but not a good tool for proper error reporting, as
S-exps are basically one big tree, and PEG grammars would just see that
as one big invalid input - we want to acknowledge that, up to that point
deep into the tree, everything was fine, and then something went wrong.

Actual parser inspired by [sxp-ruby][], some I/O routines lifted from there
(see UNLICENSE - it's public domain).

### S-exp patterns

Use case: sniff patterns like `(defn name [args] body)` in the code,
mostly used by translator.

Types: `:sym`, `:kw`, `:num`, `:str`, `:map`, `:list`, `:vec`, `:set`,
verbatim identifiers, verbatim strings, verbatim numbers, sequences
without content (matches any) or with inner patterns.

Regexp-like operators:

  - `?` - 0 or 1
  - `*` - 0 or more (greedy)
  - `+` - 1 or more (greedy)

When `*` or `+` used, matcher block will receive an Array of nodes.
When `?` used, may receive null if doesn't match.

For examples, see `spec/infra/matcher_spec.rb`.

## Translator

Basically walks the AST and produces a JST. For now, some forms that could
be implemented as macros are recognized by the translator, for example `defn`.

For example, literals are transformed to calls to `vector`, `list`, `hash-map`,
`symbol`, `keyword`, etc. Function definitions are transformed into JavaScript
functions, auto-returning the last value.

`if`, `let`, and `do` forms emit relatively naive but efficient code where possible.

For `if`, when the value is thrown away (`statement` mode), JavaScript's
`if/else` will be used. Otherwise, the ternary operator (`cond ? iftrue : iffalse`)
will be used.

`let` establishes a new scope, and renames bound symbols inside
of it, uses of which are then resolved to aliases, much like [Traceur][] does
with ES6's `let`.

`do` can be compiled either to a simple block, or to a closure, if the result
is used as an expression (it doesn't make a closure if it's just in return position,
in that case, return propagation is used).

`def`s are local variable declarations + stored into the module's `exports`
object (see `Modules` section).

Usage of the `@` operator are translated to `deref` calls. Usage of `~` and
`~@` are translated to `--unquote` calls (used internally for macro expansion).

Some checks are only done at translation time - for example, the number of keys
in a map literal, or in a let bindings vector.

As a rule, the translator generates pretty errors, like the following:

```
$ be shin -o public/js -L src/js -I src src/my/app.cljs

Invalid let form: odd number of binding forms at src/my/app.cljs:15:6 (RuntimeError)

(let [initial-tree (render) a]
      ~~~~~~~~~~~~~~~~~~~~~~~~
```

The output of the translator is what the compiler calls `JST`, which is just
really [mozilla parser API][moz-parser-api] stored in Ruby data structures.

## Generator

Uses [escodegen][] for convenience, to generate JavaScript from the JST.

Why use escodegen?

  - Proven codebase
  - Standard JavaScript AST format ([Mozilla Parser API][moz-parser-api])
  - Plays well with JavaScript source-maps (even tho not using that yet)

(So, yes, it calls into V8 to generate JS code.)

See `generator.rb`, it's pretty trivial. `jst.rb` is a thin layer of
Ruby structures above the Moz Parser API.

The only thing we can't represent is RegExp literals, see RegExp section.

Not much to say about the generator - most of the work is done in the
translator anyway.

Could replace escodegen with a pure Ruby solution for performance at some point,
maybe use [sourcemap.rb][] or a more up-to-date fork thereof?

## Modules

### AMD

cljs chose Google Closure, shin consumes & generates AMD modules.

For those, who don't know, AMD modules look like:

```javascript
(function (root, factory) {
  if (typeof define === 'function' && define.amd) {
    define(['exports', 'foo', 'bar'], factory);
  } else {
    throw "No AMD loader in sight.";
  }
})(root, function (exports, foo, bar) {
  // Execution reaches here whenever `foo` and `bar` are
  // loaded, or we have circular dependencies. Be careful.
  exports.dostuff = function() {
    return new foo.SomeType(bar.somefunction());
  });

  // Anything stuffed in `exports` will be available
  // to others. In fact, that's how foo and bar exposes
  // stuff to us in the first place!
});

```

To run specs & expand macros, shin compiler has an AMD loader built-in,
half-ruby half-JS. See `js_context.rb`.

### Namespaces

Every `.clj(s)` file read by Shin must start with a single namespace
definition, here's an example:

```clj
(ns org.example.somemodule
  (:require [some.lib :as sl :refer :all])
            [another.lib :refer [foo bar baz]]
            [js/react :as R])
```

Use the `js/` prefix to specify that you're requiring a JS module, not
a Shin module. The compiler will look into libpath and attempt to copy
it to the output directory, and warn if it can't find it. It'll also be
listed as a dependency in the AMD module definition.

### Supported loaders

Shin's output should be usable with [RequireJS][] in a browser. But
if you want to try and see if it works with [Almond][], that's cool too!

### Directory structure

As for directory structure, any `package` can either be a folder
or a dot in the pathname, so if you require `org.example.somelib.a`,
it will look for:

  - `$SOURCEPATH/org/example/somelib/a.cljs`
  - `$SOURCEPATH/org/example/somelib.a.cljs`
  - `$SOURCEPATH/org/example.somelib.a.cljs`
  - `$SOURCEPATH/org.example.somelib.a.cljs`

I'm 83% sure that's not what cljs does, but it seemed relatively sane -
go full folder if you want to, or keep your structure as flat as you want,
doesn't matter to shin.

### Non-AMD (Node.js)

There's half-baked support for generating NodeJS-style `require` directives
but it hasn't been tested whatsoever.

### Builtins

Shin ships with some pure JS files:

- `hamt.js` is [hamt+][], for data structures
- `escodegen.js` is [escodegen][], only there for compiler use

And of course, `cljs/core.cljs` and `cljs/core.clj` (for macros),
which are required (with :refer :all) into all modules by default.

(`:refer-clojure` is not implemented yet, so no exclusion is possible.
See [Issue #20](https://github.com/memoways/shin/issues/20))

### core lib Completion

At this point, a sizable portion of `cljs.core` has been ported over, but
an even more sizable portion remains untouched. Hopefully the balance will
tip eventually, but with 611 vars in `clojure.core` at the time of this
writing, my money's on Rich.

The full `clojure.string` package has been adapted from ClojureScript and
is covered by specs.

## Specs

RSpec 3.x, ran [on travis-ci][travis].

Two types of specs:

### Infrastructure specs

For now, mostly testing the S-exp pattern matching system.

Custom matcher, `ast_match` (see `spec/matchers.rb`), basic structure
is `expect(sexp_source).to ast_match(sexp_pattern)`.

### Language specs

Custom matcher `have_output` (see `spec/matchers.rb`), basic structure
is `expect(code).to have_output(output)`. Shin code calls out to `print`,
all calls joined by a space character.

Simple:

```ruby
RSpec.describe "Language", "if" do
  it "doesn't evaluate if-false, when false" do
    expect(%Q{
      (if true () (print "Don't print me!"))
    }).to have_output("")
  end
end
```

With macros:

```ruby
RSpec.describe "Language", "macros" do
  it "separates compile-time & run-time correctly" do
    expect(
      :source => %Q{ (let [a (foobar)] (print (typeof a))) }
      :macros => %Q{ (defmacro foobar [] `(print "That'll be at runtime, thanks")) }
    ).to have_output("function")
  end
end
```

Yes, it'd be cleaner if one didn't have to write `print` in every spec, but you'd
be surprised what you can't test with such rudimentary infrastructure.

## Mangling

Since Clojure is very liberal in what identifiers are, and JavaScript isn't,
Shin mangles identifiers.

For example, `contains?` is mangled to `contains$q`. `$` itself is escaped as
`$$`. As most of Shin, it's so naive it's cute, but hey, it works really well.

See `mangler.rb` to see the most current translation table. If you ever modify
that, keep `shin.js` in sync.

## Macros

Basic idea: macros are executable code, so let's compile & execute them.
That's `mutator.rb`'s job.

When macro expansion is required:

  - Compile macro def to JS, as if it was a function
  - Compile dummy module that does `(yield (pr-str (macro-invocation)))`
  - `pr-str` will serialize our code to textual S-expr representation
  - `yield` will give it back to the Ruby side (compiler)
  - We then parse it back so we have a `Shin::AST` repr of the result
  - Then we replace the invocation by its expansion
  - Tadaa.

That means we actually invoke V8 during compilation, if macros are involved.
Also, the order in which stuff is done is still kind of shady, especially
considering `cljs.core` is required (with `:refer :all`) everywhere by
default. If macros break don't hit me!

`gensym` manual calling is supported, however the compiler believes in big
numbers and will not attempt to check that they, in fact, do not collide with
each other (so far).

Automatic `gensym` is in, which means you can write stuff like that:

```
(defmacro nonsense [a b c]
  `(let [d# (str ~a ~b)]
     (print d# ~c d#)))
```

And it'll be transformed (at parse time) to something like that:

```
(defmacro nonsense [a b c]
  (let [d2121 (gensym "d")]
    `(let [~d2121 (str ~a ~b)]
      (print ~d2121 ~c ~d2121))))
```

Due to the way the AST is passed to "macros compiled to JS code", we lose
location information inside the macro invocation. This could be fixed
with metadata, if we had metadata support. Or with a reverse lookup map
on the mutator's side.

## Destructuring

Full Clojure destructuring is supported, with vectors and maps, in let forms,
function definitions and macro definitions, nested as deep as you want.

It's one of the reason Clojure is so cool, read about it:

  - [On clojure.org](http://clojure.org/special_forms#Special%20Forms--Binding%20Forms%20(Destructuring))
  - [On clojuredocs.org](http://clojuredocs.org/concepts/destructuring)
  - [On Jay Field's blog](http://blog.jayfields.com/2010/07/clojure-destructuring.html)

## Data structures

Using [hamt+][] by Matt Bierner. Doesn't use [mori][] because, c'mon,
[where's the fun][structs-in-js] in that?

Everything is immutable, persistent. Manipulation is slower than
native JS structures, but comparing should be faster. Watch
[what Szymon says](http://vimeo.com/86694423) if you don't know
about Clojure-style persistent data structures.

### PersistentArrayMap

Straight up [hamt+][] tries, wrapped in a callable object (see `shin.js` for
the trick) so it behaves like a Clojure map.

Takes advantages of [hamt+][]'s `mutate` so that huge literals are faster
to construct than `assoc`'ing one by one. Could use the same trick to make
a fast JSON loader, for instance.

### Sets

Not even a real type, right now just a `PersistentArrayMap` with values set
to `true`. Needs a whole lot of love.

### PersistentVector

Straight up naive, basically a PersistentArrayMap with integer keys, but
[hamt+][] doesn't guarantee key ordering and probably does sub-optimal
hashing, so we should come up with something better, probably a fork
of [hamt+][] based on [ancient-oak][]'s work on arrays/vectors.

### List

Similar to ClojureScript

### Cons

Similar to ClojureScript

### LazySeq

None yet, see [Issue #2](https://github.com/memoways/shin/issues/2).

### Keyword, Symbol

Callable (to allow `(:mykey map)` or `('mysym map)`, usable in calls
to `name`, e.g. `(= "foobar" (name :foobar))` is true, same goes for
symbols.

## Regexps

Mostly ClojureScript-equivalent with `re-find`, `re-matches` and `re-matcher`.

Weird API but whatevs, clj gonna be clj.

RegExp literal, `#"[A-Z]IAMA a RegExp AMA"`, translates to RegExp constructor
call rather than JS RegExp because that's the only part of the [Mozilla Parser
API][moz-parser-api] that does *not* serialize to JSON. :hankey:

## Atoms

`atom`, `add-watch`, `remove-watch` and the deref operator `@` work pretty much
as advertised. Implementation is deceptively simple though, don't way you weren't
warned.

## Special forms

We've got:

  - if
  - let
  - fn
  - do
  - quote
  - def, defn, defmacro
  - closures, e.g. `#()`
  - loop/recur

There is no try (yet).

## JS interop

Primitives from ClojureScript, e.g.

```clj
(let [o (Thing. "foo")] ; 'o' is now bound to a new Thing instance
  (.setName o "fido") ; create a new 'MyObject' with arguments a, b, c
  (prn "Dog name: " (.-name o)) ; access field 'name' from fido
  )
```

Also: `aget`, `aset`, `clj->js`, and `js->clj`.

Lifts JS literals from [ki][], e.g.

```clj
(let [o {$ "a" 1 "b" 2} ; o is {a: 1, b: 2} in JS
      a [$ 1 2 3]])     ; a is [1, 2, 3] in JS
```

## Types / OO

Internal data structures are JS OO, but `deftype`, `defprotocol`, `satisfies?`,
`reify`, etc. aren't implemented yet.

@webbedspace has an [interesting idea for records](https://twitter.com/webbedspace/status/535423142286479360),
thanks to @jcoglan for yelling about stuff.

## Interfaces

### CLI

Run `shin -h` and it'll tell you all about it. Subject to changes.

### API

*Very* subject to changes, haven't found the right mix of convenient interface,
flexible pipeline, concise code yet. Time will tell.

But basically, use `compiler.rb` or roll your own pipeline by running
Parser, NsParser, Mutator, Translator, Generator, and outputting yourself.

## Thanks

Thanks to [Luca Antiga](https://twitter.com/lantiga) for the inspiration and
for ki, and to Nicolas Goy, Meine Goy, Fabrice Truillot de Chambrier, Ulrich
Fischer, Dimiter Petrov, Jens Nockert, Romain Ruetschi, Arnaud Bénard, for
all the support.

## License

Shin is released under the MIT license. See `LICENSE.txt` for the complete text.

Hamt+ is also MIT-licensed, see its own repo: [hamt+][].

Significant parts of standard library is adapted / copied from
[ClojureScript][cljs], which is distributed under the Eclipse Public License
1.0. Here's it's copyright license, just in case:

```
Copyright (c) Rich Hickey. All rights reserved. The use and
distribution terms for this software are covered by the Eclipse
Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
which can be found in the file epl-v10.html at the root of this
distribution. By using this software in any fashion, you are
agreeing to be bound by the terms of this license. You must
not remove this notice, or any other, from this software.
```

[cljs]: https://github.com/clojure/clojurescript
[ki]: http://ki-lang.org/
[shameless-plug]: http://fasterthanlime.com/blog/2014/sexps-in-your-browser/

[treetop]: https://github.com/nathansobo/treetop
[sxp-ruby]: https://github.com/bendiken/sxp-ruby/

[escodegen]: https://github.com/Constellation/escodegen
[moz-parser-api]: https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
[sourcemap.rb]: https://github.com/maccman/sourcemap

[travis]: https://travis-ci.org/memoways/shin

[hamt+]: https://github.com/mattbierner/hamt_plus
[ancient-oak]: https://github.com/brainshave/ancient-oak/
[mori]: https://github.com/swannodette/mori
[structs-in-js]: https://gist.github.com/fasterthanlime/d682abf83bdf624f0ef8

[RequireJS]: http://requirejs.org/
[Almond]: https://github.com/jrburke/almond
[Traceur]: https://github.com/google/traceur-compiler

