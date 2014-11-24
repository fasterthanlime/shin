
(function (root, factory) {
  if (typeof exports === 'object') {
    var hamt = require('hamt');
    factory(exports, hamt);
  } else if (typeof define === 'function' && define.amd) {
    define(['exports', 'hamt'], factory)
  } else {
    throw "No AMD loader detected, shin code can't run.";
  }
})(this, function (exports, hamt) {
  exports.namespaces = {}

  exports.init = function (self, ns_name) {
    if (exports.namespaces[ns_name] === undefined) {
      exports.namespaces[ns_name] = { vars: {} };
    }
    self._shin_ns_name = ns_name;
    self._shin_ns_ctx = self;
  };

  exports.intern = function (obj) {
    for (var e in obj) {
      if (obj.hasOwnProperty(e)) {
        this[e] = obj[e];
      }
    }
  };

  exports.mangle = function (name) {
    return name
      .replace(/-/g,  '$_')
      .replace(/\?/g, '$q')
      .replace(/\!/g, '$e')
      .replace(/\*/g, '$m')
      .replace(/\//g, '$d')
      .replace(/\+/g, '$p')
      .replace(/=/g,  '$l')
      .replace(/>/g,  '$g')
      .replace(/</g,  '$s')
      .replace(/\./g, '$d')
      .replace(/%/g,  '$c')
      ;
  };

  (function () {
    var m = exports.mangle;
    var core = {};
    var def = function (name, f) {
      core[m(name)] = f;
    }
    var lookup = function (name) {
      return core[m(name)];
    }

    /* Data structures */ 

    def('hamt', hamt);

    var Colls = {};

    /* PersistentVector */

    (function () {
      var PersistentVector = Colls.PersistentVector = function (arg, offset, count) {
        var vector = function(key) {
          return lookup('get')(vector, key);
        }
        vector.__proto__ = PersistentVector.prototype;

        if (typeof arg === 'function') {
          var f = arg;
          var h = offset;
          vector.h = hamt.mutate(f, h ? h : hamt.make({
            hash:  lookup('hash'),
            keyEq: lookup('=')
          }));
          vector.offset = 0;
          vector._count = hamt.count(vector.h);
        } else {
          vector.h = arg;
          vector.offset = offset;
          vector._count = count;
        }
        Object.freeze(vector);
        return vector;
      };

      PersistentVector.prototype = Object.create(Function.prototype);

      PersistentVector.EMPTY = new PersistentVector(function () {});

      ['vector?', 'collection?', 'sequential?',
      'associative?', 'counted?', 'indexed?',
      'reduceable?', 'seqable?', 'reversible?'].forEach(function (quality) {
        PersistentVector.prototype[m(quality)] = true;
      });

      PersistentVector.prototype.is_empty = function(n) {
        return this._count == 0;
      }

      PersistentVector.prototype.assoc = function() {
        var args = arguments;
        return new PersistentVector(function (h) {
          var count = args.length / 2;
          for (var i = 0; i < count; i++) {
            var key = args[i * 2], val = args[i * 2 + 1];
            hamt.set(key, val, h);
          }
        }, this.h);
      }

      PersistentVector.prototype.map = function(f) {
        var self = this;
        return new PersistentVector(function (h) {
          for (var i = 0; i < self._count; i++) {
            hamt.set(i, f(self.nth(i)), h);
          }
        });
      }

      PersistentVector.prototype.get = function(n) {
        return this.nth(n);
      }

      PersistentVector.prototype.nth = function(n) {
        return hamt.get(this.offset + n, this.h);
      }
      
      PersistentVector.prototype.count = function() {
        return this._count;
      }

      PersistentVector.prototype.first = function() {
        return hamt.get(this.offset, this.h);
      }

      PersistentVector.prototype.last = function() {
        return hamt.get(this._count - 1 - this.offset, this.h);
      }

      PersistentVector.prototype.subvec = function (start, end) {
        if (typeof end === 'undefined') { end = this._count; };
        if (start > end) {
          throw ("in subvec, start > end " + start + " > " + end);
        }
        if (start > this._count) {
          throw ("index out of bounds: start = " + start + ", count = " + this._count);
        }
        if (start === end) {
          return Colls.PersistentVector.EMPTY;
        }
        var count = end - start;
        if (count > this._count) {
          throw ("index out of bounds: count = " + count, ", this._count = " + this._count);
        }
        return new Colls.PersistentVector(this.h, this.offset + start, count);
      }

      PersistentVector.prototype.printString = function () {
        var s = '[';
        var first = true;
        var pr_str = lookup('pr-str');
        for (var i = 0; i < this._count; i++) {
          if (!first) {
            s += ' ';
          }
          s += pr_str(this.nth(i));
          first = false;
        }
        return s + ']';
      }

      PersistentVector.prototype.drop = function(n) {
        if (n == 0) { return this }
        return this.subvec(n);
      }

      PersistentVector.prototype.next = function() {
        // FIXME: probably not right.
        if (this._count == 0) { return null; }
        return this.subvec(1);
      }

      PersistentVector.prototype.rest = function() {
        // FIXME: probably not right.
        return this.subvec(1);
      }

      PersistentVector.prototype.take = function(n) {
        if (n == 0) { return PersistentVector.EMPTY; }
        if (n == this._count) { return this; }
        return this.subvec(0, n);
      }

      PersistentVector.prototype.take_while = function(f) {
        // should be lazy.
        var n = 0;
        for (; n < this._count && f(this.nth(n)); n++) { }
        return this.subvec(0, n);
      }

      PersistentVector.prototype.drop_while = function(f) {
        // should be lazy.
        var n = 0;
        for (; n < this._count && f(this.nth(n)); n++) { }
        return this.subvec(n);
      }

      PersistentVector.prototype.toJS = function () {
        var r = Array(this._count);
        var toJS = lookup('clj->js');
        for (var i = 0; i < this._count; i++) {
          r[i] = toJS(this.nth(i));
        }
        return r;
      }

      def('PersistentVector', Colls.PersistentVector);
    })();

    /* PersistentArrayMap */

    (function () {
      var PersistentArrayMap = Colls.PersistentArrayMap = function (f, h) {
        var map = function (key) {
          return lookup('get')(map, key);
        }
        map.__proto__ = PersistentArrayMap.prototype;
        map.h = hamt.mutate(f, h ? h : hamt.make({
          hash:  lookup('hash'),
          keyEq: lookup('=')
        }));
        Object.freeze(map);
        return map;
      };

      PersistentArrayMap.prototype = Object.create(Function.prototype);

      ['map?', 'collection?', 'associative?',
      'counted?', 'seqable?'].forEach(function (quality) {
        PersistentArrayMap.prototype[m(quality)] = true;
      });

    PersistentArrayMap.prototype.assoc = function() {
      var args = arguments;
      return new PersistentArrayMap(function (h) {
        var count = args.length / 2;
        for (var i = 0; i < count; i++) {
          var key = args[i * 2], val = args[i * 2 + 1];
          hamt.set(key, val, h);
        }
      }, this.h);
    }

    PersistentArrayMap.prototype.dissoc = function() {
      var args = arguments;
      return new PersistentArrayMap(function (h) {
        var count = args.length;
        for (var i = 0; i < count; i++) {
          hamt.remove(args[i], h);
        }
      }, this.h);
    }

    PersistentArrayMap.prototype.get = function(key) {
      return hamt.get(key, this.h);
    }

    PersistentArrayMap.prototype.printString = function () {
      var s = '{';
      var first = true;
      var pr_str = lookup('pr-str');
      var pairs = hamt.pairs(this.h);
      for (var i = 0; i < pairs.length; i++) {
        var pair = pairs[i];
        if (!first) {
          s += ' ';
        }
        s += pr_str(pair[0]);
        s += ' ';
        s += pr_str(pair[1]);
        first = false;
      }
      return s + '}';
    }

    PersistentArrayMap.prototype.toJS = function () {
      var r = {};
      var toJS = lookup('clj->js');
      var pairs = hamt.pairs(this.h);
      for (var i = 0; i < pairs.length; i++) {
        var pair = pairs[i];
        r[toJS(pair[0])] = toJS(pair[1]);
      }
      return r;
    }

    def('PersistentArrayMap', Colls.PersistentArrayMap);
    })();

    /* PersistentList */

    (function () {
      var PersistentList = Colls.PersistentList = function (car, cdr) {
        this.car = car;
        this.cdr = cdr;
        Object.freeze(this);
      };

      PersistentList.EMPTY = new PersistentList(null, null);

      ['list?', 'seq?', 'collection?', 'sequential?',
      'counted?', 'reduceable?', 'seqable?'].forEach(function (quality) {
        PersistentList.prototype[m(quality)] = true;
      });

    PersistentList.prototype.cons = function (x) {
      return new PersistentList(x, this);
    }

    PersistentList.prototype.conj = function (x) {
      return new PersistentList(x, this);
    }

    PersistentList.prototype.first = function () {
      return this.car;
    }

    PersistentList.prototype.last = function () {
      if (this.cdr) {
        return this.cdr.last();
      } else {
        return this.car;
      }
    }

    PersistentList.prototype.nth = function(n) {
      if (n == 0) {
        return this.car;
      } else if (this.cdr) {
        return this.cdr.nth(n - 1);
      } else {
        throw "index out of bounds";
      }
    }
    
    PersistentList.prototype.count = function() {
      var count = 0;
      for (var c = this; c; c = c.cdr, count++) { }
      return count;
    }

    PersistentList.prototype.drop = function (n) {
      if (n == 0) { return this }
      if (n == 1) { return this.cdr ? this.cdr : PersistentList.EMPTY }
      if (this.cdr) { return this.cdr.drop(n - 1) }
      return PersistentList.EMPTY;
    }

    PersistentList.prototype.take = function(n) {
      // this is *not* efficient. lazy-seq would help :|
      if (n == 0) { return PersistentList.EMPTY; }
      if (n == 1) { return new PersistentList(this.car, null); }
      return new PersistentList(this.car, this.cdr.take(n - 1));
    }

    PersistentList.prototype.take_while = function(f) {
      // should be lazy.
      var n = 0;
      for (var c = this; c && f(c.car); c = c.cdr, n++) {}
      return this.take(n);
    }

    PersistentList.prototype.drop_while = function(f) {
      // should be lazy.
      var c = this;
      for (; c && f(c.car); c = c.cdr) {}
      if (!c) { return PersistentList.EMPTY; }
      return c;
    }

    PersistentList.prototype.map = function (f) {
      return new PersistentList(f(this.car), this.cdr ? this.cdr.map(f) : null);
    }

    PersistentList.prototype.printString = function () {
      var s = '(';
      var first = true;
      var pr_str = lookup('pr-str');
      for (var c = this; c; c = c.cdr) {
        if (!first) {
          s += ' ';
        }
        s += pr_str(c.car);
        first = false;
      }
      return s + ')';
    }

    PersistentList.prototype.toJS = function () {
      var r = [];
      var toJS = lookup('clj->js');
      for (var c = this; c; c = c.cdr) {
        r.push(toJS(c.car));
      }
      return r;
    }

    })();

    /* Keyword */

    (function () {
      var Keyword = Colls.Keyword = function (name) {
        var kw = function (coll) {
          return lookup('get')(coll, kw);
        };
        kw.__proto__ = Keyword.prototype;
        kw._name = name;
        Object.freeze(kw);
        return kw;
      };

      Keyword.prototype = Object.create(Function.prototype);

      Keyword.prototype.toJS = function () {
        return this._name;
      };

      ['keyword?'].forEach(function (quality) {
        Keyword.prototype[m(quality)] = true;
      });

      Keyword.prototype.printString = function () {
        return ":" + this._name;
      };
    })();

    /* Symbol */

    (function () {
      var Symbol = Colls.Symbol = function (name) {
        var sym = function (coll) {
          return lookup('get')(coll, sym);
        };
        sym.__proto__ = Symbol.prototype;
        sym._name = name;
        Object.freeze(sym);
        return sym;
      };

      Symbol.prototype = Object.create(Function.prototype);

      Symbol.prototype.toJS = function () {
        return this._name;
      };

      ['symbol?'].forEach(function (quality) {
        Symbol.prototype[m(quality)] = true;
      });

      Symbol.prototype.printString = function () {
        return this._name;
      };
    })();

    /* Symbol */

    (function () {
      var Unquote = Colls.Unquote = function (inner, splice) {
        this.inner = inner;
        this.splice = splice;
      };

      ['unquote?'].forEach(function (quality) {
        Unquote.prototype[m(quality)] = true;
      });

      Unquote.prototype.printString = function () {
        var r = '~', pr_str = lookup('pr-str');
        if (this.splice) { r += '@' }
        r += pr_str(this.inner);
        return r;
      };
    })();

    def('--unquote', function(inner, splice) {
      return new Colls.Unquote(inner, splice);
    })

    def('--selfcall', function (fn, _args) {
      var args = Array.prototype.slice.call(_args, 1)
      fn.apply(_args[0], args)
    })

    /* End collections / types */

    def('vector', function () {
      var args = arguments;
      return new Colls.PersistentVector(function(h) {
        for (var i = 0; i < args.length; i++) {
          hamt.set(i, args[i], h);
        }
      });
    });

    def('vec', function (coll) {
      if (coll instanceof Array) {
        return new Colls.PersistentVector(function(h) {
          for (var i = 0; i < coll.length; i++) {
            hamt.set(i, coll[i], h);
          }
        });
      } else {
        throw "vecs of non-arrays: stub";
      }
    });

    def('hash-map', function () {
      var args = arguments;
      if (args.length % 2 != 0) {
        throw "Odd number of elements passed to hash-map";
      }
      return new Colls.PersistentArrayMap(function(h) {
        for (var i = 0, max = args.length / 2; i < max; i++) {
          hamt.set(args[(i * 2)], args[(i * 2) + 1], h);
        }
      });
    });

    def('set', function (els) {
      var args = [];
      for (var i = 0; i < els.length; i++) {
        args.push(els[i]);
        args.push(true);
      }
      return lookup('hash-map').apply(null, args);
    });


    def('list', function recur () {
      if (arguments.length == 0) {
        return Colls.PersistentList.EMPTY;
      }

      var car = arguments[0], cdr = null;
      if (arguments.length > 1) {
        cdr = recur.apply(null, Array.prototype.slice.call(arguments, 1));
      }
      return new Colls.PersistentList(car, cdr); 
    });

    def('keyword', function (name) {
      return new Colls.Keyword(name);
    });

    def('symbol', function (name) {
      return new Colls.Symbol(name);
    });

    def('get', function (coll, key, not_found) {
      var r = coll.get(key)
      if (r) { return r; }
      if (typeof not_found != 'undefined') { return not_found };
      return null;
    });

    def('empty?', function (coll, key) {
      return coll.is_empty();
    });

    def('nth', function (coll, n) {
      return coll.nth(n);
    });

    def('nthnext', function (coll, n) {
      // Returns the nth next of coll, (seq coll) when n is 0.
      if (n == 0) { return lookup('seq')(coll); };
      var curr = coll, next = lookup('next');
      for (; n > 0; curr = next(curr), n--) { }
      return curr;
    });

    def('nthrest', function (coll, n) {
      // Returns the nth rest of coll, coll when n is 0.
      if (n == 0) { return coll; };
      var curr = coll, rest = lookup('rest');
      for (; n > 0; curr = rest(curr), n--) { }
      return curr;
    });

    def('seq', function (x) {
      // TODO: implement.
      // Returns a seq on the collection. If the collection is
      // empty, returns nil.  (seq nil) returns nil. seq also works
      // on Strings, native Java arrays (of reference types) and any
      // objects that implement Iterable.
      return x;
    });

    def('next', function (x) {
      // Returns a seq of the items after the first. Calls seq on its
      // argument. If there are no more items, returns nil
      return x.next();
    })

    def('rest', function (x) {
      // Returns a possibly empty seq of the items after the first. Calls seq
      // on its argument.
      return x.rest();
    })

    def('assoc', function (coll) {
      var args = Array(arguments.length - 1);
      for (var i = 1; i < arguments.length; i++) {
        args[i - 1] = arguments[i];
      }
      if (args.length % 2 != 0) { throw "Odd number of kvs to assoc"; }
      return coll.assoc.apply(coll, args);
    });

    def('dissoc', function (coll) {
      var args = Array(arguments.length - 1);
      for (var i = 1; i < arguments.length; i++) {
        args[i - 1] = arguments[i];
      }
      return coll.dissoc.apply(coll, args);
    });

    def('count', function (coll) {
      return coll.count();
    });

    def('last', function (coll) {
      return coll.last();
    });

    def('first', function (coll) {
      return coll.first();
    });

    def('drop', function (n, coll) {
      // FIXME: lazy
      return coll.drop(n);
    });

    def('take', function (n, coll) {
      // FIXME: lazy
      return coll.take(n);
    });

    def('take-while', function (n, coll) {
      // FIXME: lazy
      return coll.take_while(n);
    });

    def('drop-while', function (n, coll) {
      // FIXME: lazy
      return coll.drop_while(n);
    });

    def('complement', function (f) {
      return function () { return !f.apply(null, arguments); }
    });

    def('rest', function (coll) {
      // FIXME: lazy-seq
      return lookup('drop')(1, coll);
    });

    def('conj', function(coll, x) {
      // FIXME: probably not right
      return coll.conj(x);
    });

    def('cons', function(x, seq) {
      // FIXME: probably not right
      return seq.cons(x);
    });

    def('subvec', function (coll, start, end) {
      return coll.subvec(start, end);
    });

    def('map', function (f, coll) {
      // FIXME: accept multiple colls
      // FIXME: lazy
      return coll.map(f);
    })

    def('reduce', function (f, z, coll) {
      var first = lookup('first'), rest = lookup('rest');

      if (typeof coll === 'undefined') {
        coll = z;
        z = undefined;
      }
      if (typeof z === 'undefined') {
        var a = first(coll);
        coll = rest(coll);
        var b = first(coll);
        coll = rest(coll);
        z = f(a, b);
      }
      empty = lookup('empty?')
      while (!empty(coll)) {
        z = f(z, first(coll));
        coll = rest(coll);
      }
      return z;
    });

    def('hash', function (x) {
      if (x[m('symbol?')] || x[m('keyword?')]) {
        return hamt.hash(x._name);
      }
      return hamt.hash(x);
    });

    ['list?', 'seq?', 'vector?', 'map?', 'set?',
      'collection?', 'sequential?', 'associative?',
      'counted?', 'indexed?', 'reduceable?',
      'seqable?', 'reversible?'].forEach(function (quality) {
        def(quality, function (coll) {
          return !!coll[m(quality)];
        });
      })

    /* Regexp */

    def('re-matches', function (pattern, str) {
      var matches = str.match(new RegExp('^' + pattern.source + '$'));
      if (matches === null) {
        return null;
      } else if (matches.length == 1) {
        return matches[0];
      } else {
        return lookup('vec')(matches);
      }
    });

    def('re-matcher', function (pattern, str) {
      return {
        _type: "shin.Matcher",
      pattern: pattern,
      str: str,
      index: 0
      }
    });

    def('re-find', function (pattern, str) {
      var matches = null;
      if (pattern._type === "shin.Matcher") {
        var matcher = pattern;
        var matches = matcher.pattern.exec(matcher.str.substring(matcher.index));
        if (matches) {
          matcher.index += (matches.index + matches[0].length);
        }
      } else {
        matches = pattern.exec(str);
      }

      if (matches === null) {
        return null;
      } else if (matches.length == 1) {
        return matches[0];
      } else {
        return lookup('vec')(matches);
      }
    });

    /* Atom */

    (function () {
      var Atom = Colls.Atom = function (val) {
        this._value = val;
        this.watchers = new Colls.PersistentArrayMap(function (h) {});
      };

      Atom.prototype.deref = function () {
        return this._value;
      }

      Atom.prototype.reset = function (val) {
        var old = this._value;
        var keys = hamt.keys(this.watchers.h);
        for (i in keys) {
          var key = keys[i];
          var watcher = this.watchers(key);
          watcher(key, this, old, val);
        }
        return this._value = val;
      }
      
      Atom.prototype.addWatch = function (key, fn) {
        this.watchers = this.watchers.assoc(key, fn);
        return this;
      }

      Atom.prototype.removeWatch = function (key) {
        this.watchers = this.watchers.dissoc(key);
        return this;
      }

      Atom.prototype.swap = function () {
        var f = arguments[0], params = [this._value];
        for (var i = 1; i < arguments.length; i++) {
          params.push(arguments[i]);
        }
        return this.reset(arguments[0].apply(null, params));
      }

    })();

    def('atom', function (val) {
      return new Colls.Atom(val);
    });

    def('deref', function (atom) {
      return atom.deref();
    });

    def('reset!', function (atom, val) {
      return atom.reset(val);
    });

    def('swap!', function () {
      var atom = arguments[0], params = [];
      for (var i = 1; i < arguments.length; i++) {
        params.push(arguments[i]);
      }
      return atom.swap.apply(atom, params);
    });

    /* Misc */

    def('name', function (keyword) {
      return keyword._name;
    });

    def('nil?', function (x) {
      return x === null;
    });

    function truthy (x) {
      return x === false || x == null ? false : true;
    };

    function falsey (x) {
      return !truthy(x);
    };

    def('not', function (x) {
      return !truthy(x);
    });

    def('dec', function (x) { return x - 1; });
    def('inc', function (x) { return x + 1; });

    def('even?', function (x) { return x % 2 == 0; });
    def('odd?',  function (x) { return x % 2 != 0; });

    var equals2 = function (l, r) {
      if (l === r) { return true };
      if (!l || !r) { return false };
      if (l[m('list?')] && r[m('list?')]) {
        if (!equals2(l.car, r.car)) { return false };
        return equals2(l.cdr, r.cdr);
      }
      if (l[m('vector?')] && r[m('vector?')]) {
        if (l.h === r.h &&
            l.offset === r.offset &&
            l._count === r._count) { return true }
        var max = l._count;
        if (r._count != max) { return false };
        for (var i = 0; i < max; i++) {
          if (!equals2(l.nth(i), r.nth(i))) { return false }
        }
        return true;
      }
      if (l[m('map?')] && r[m('map?')]) {
        var kl = hamt.keys(l.h), kr = hamt.keys(r.h);
        if (kl.length != kr.length) { return false };
        // inefficient, I know! but least has shortcut evaluation.
        for (var i = 0; i < kl.length; i++) {
          if (!equals2(hamt.get(kl[i], l.h), hamt.get(kl[i], r.h))) {
            return false;
          }
          if (!equals2(hamt.get(kr[i], l.h), hamt.get(kr[i], r.h))) {
            return false;
          }
        }
        return true;
      }
      if (l[m('symbol?')] && r[m('symbol?')]) {
        return l._name == r._name;
      }
      if (l[m('keyword?')] && r[m('keyword?')]) {
        return l._name == r._name;
      }
      return false;
    }

    def('=', function () {
      var count = arguments.length, i = 1, lhs = arguments[0];
      for (var i = 1; i < count; i++) {
        var rhs = arguments[i];
        if (!equals2(lhs, rhs)) {
          return false;
        }
        lhs = rhs;
      }
      return true; 
    });

    def('not=', function () {
      return !lookup('=').apply(null, arguments); 
    });

    def('+', function() {
      var res = 0.0;
      for (var i=0; i<arguments.length; i++) {
        res += arguments[i];
      }
      return res;
    });

    def('-', function() {
      var res = arguments[0];
      for (var i=1; i<arguments.length; i++) {
        res -= arguments[i];
      }
      return res;
    });

    def('*', function() {
      var res = 1.0;
      for (var i=0; i<arguments.length; i++) {
        res *= arguments[i];
      }
      return res;
    });

    def('/', function() {
      var res = arguments[0];
      for (var i=1; i<arguments.length; i++) {
        res /= arguments[i];
      }
      return res;
    });

    def('mod', function (a, b) {
      return a % b;
    });

    def('<', function () {
      var res = true;
      for (var i=0; i<arguments.length-1; i++) {
        res = res && arguments[i] < arguments[i+1];
        if (!res) break;
      }
      return res;
    });

    def('>', function () {
      var res = true;
      for (var i=0; i<arguments.length-1; i++) {
        res = res && arguments[i] > arguments[i+1];
        if (!res) break;
      }
      return res;
    });

    def('<=', function () {
      var res = true;
      for (var i=0; i<arguments.length-1; i++) {
        res = res && arguments[i] <= arguments[i+1];
        if (!res) break;
      }
      return res;
    });

    def('>=', function() {
      var res = true;
      for (var i=0; i<arguments.length-1; i++) {
        res = res && arguments[i] >= arguments[i+1];
      }
      return res;
    });

    def('pr-str', function pr_str (x) {
      var type = typeof x;
      if (type === "undefined" || x === null) {
        return 'nil';
      } else if (type === "string") {
        return '"' + x + '"';
      } else if (type === "number") {
        return String(x);
      } else if (x instanceof Array) {
        var s = '[$';
        for (var i in x) {
          s += ' ';
          s += pr_str(x[i]);
        }
        s += ']';
        return s;
      } else if (x.printString) {
        return x.printString();
      } else if (type === "object") {
        var s = '{$';
        var keys = Object.keys(x);
        for (var key in x) {
          var value = x[key];
          s += ' ';
          s += pr_str(key);
          s += ' ';
          s += pr_str(value);
        }
        s += '}';
        return s;
      } else {
        return "" + x;
      }
    });

    def('prn', function() {
      console.log.apply(console,arguments);
    });

    def('str', function() {
      var args = [];
      for (var i = 0; i < arguments.length; i++) {
        var arg = arguments[i];
        if (typeof arg === 'undefined' || arg === null) {
          arg = '<nil>';
        } else if (arg.toString) {
          arg = arg.toString();
        }
        args.push(arg);
      }
      return String.prototype.concat.apply('', args);
    });

    def('aget', function (obj, key) {
      return obj[key];
    });

    def('aset', function (obj, key, val) {
      return obj[key] = val;
    });

    def('apply', function (f, args) {
      return f.apply(null, lookup('clj->js')(args));
    });

    def('clj->js', function (x) {
      var type = typeof x;
      if (type === "undefined") {
        return null;
      } else if (type === "string" || type === "number") {
        return x;
      } else if (x.toJS) {
        return x.toJS();
      } else {
        return x;
      }
    });

    def('js->clj', function (x) {
      var type = typeof x;
      if (type == "string" || type == "number") {
        return x;
      } else if (x instanceof Array) {
        return lookup('vector').apply(null, x);
      } else {
        var els = [];
        Object.keys(x).forEach(function (key) {
          els.push(key);
          els.push(x[key]);
        });
        return lookup('hash-map').apply(null, els);
      }
    });

    def('add-watch', function(reference, key, fn) {
      return reference.addWatch(key, fn);
    });

    def('remove-watch', function(reference, key) {
      return reference.removeWatch(key);
    });

    exports.intern.call(exports, core);
  })();
});

