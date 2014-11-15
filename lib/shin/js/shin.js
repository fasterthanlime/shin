
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
  exports.init = function (self, ns_name) {
    if (exports.namespaces[ns_name] === undefined) {
      exports.namespaces[ns_name] = { vars: {} };
    }
    self._shin_ns_name = ns_name;
    self._shin_ns_ctx = self;
    exports.intern.call(self, exports.modules.core);
    exports.intern.call(self, exports.modules);
    exports.intern.call(self, exports.namespaces[_shin_ns_name].vars);
  };

  exports.intern = function (obj) {
    for (var e in obj) {
      if (obj.hasOwnProperty(e)) {
        this[e] = obj[e];
      }
    }
  };

  exports.namespaces = {}

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
      ;
  };

  exports.modules = {
    core: (function () {
      var m = exports.mangle;
      var core_aliases = {};
      var def = function (name, f) {
        core_aliases[m(name)] = f;
      }
      var lookup = function (name) {
        return core_aliases[m(name)];
      }

      /* Data structures */ 

      def('hamt', hamt);

      var Colls = {};

      /* PersistentVector */

      (function () {
        var PersistentVector = Colls.PersistentVector = function (arg, offset, count) {
          if (typeof arg === 'function') {
            this.h = hamt.mutate(arg, hamt.make({
              hash:  lookup('hash'),
              keyEq: lookup('=')
            }));
            this.offset = 0;
            this.count = hamt.count(this.h);
          } else {
            this.h = arg;
            this.offset = offset;
            this.count = count;
          }
          Object.freeze(this);
        };

        PersistentVector.EMPTY = new PersistentVector(function () {});

        ['vector?', 'collection?', 'sequential?',
         'associative?', 'counted?', 'indexed?',
         'reduceable?', 'seqable?', 'reversible?'].forEach(function (quality) {
          PersistentVector.prototype[m(quality)] = true;
        });

        PersistentVector.prototype.is_empty = function(n) {
          return this.count == 0;
        }

        PersistentVector.prototype.nth = function(n) {
          return hamt.get(this.offset + n, this.h);
        }

        PersistentVector.prototype.first = function() {
          return hamt.get(this.offset, this.h);
        }

        PersistentVector.prototype.last = function() {
          return hamt.get(this.count - 1 - this.offset, this.h);
        }

        PersistentVector.prototype.subvec = function (start, end) {
          if (typeof end === 'undefined') { end = this.count; };
          if (start > end) {
            throw ("in subvec, start > end " + start + " > " + end);
          }
          if (start > count) {
            throw ("index out of bounds: start = " + start + ", count = " + count);
          }
          if (start === end) {
            return Colls.PersistentVector.EMPTY;
          }
          var count = end - start;
          if (count > this.count) {
            throw ("index out of bounds: count = " + count, ", this.count = " + this.count);
          }
          return new Colls.PersistentVector(this.h, this.offset + start, count);
        }

        PersistentVector.prototype.printString = function () {
          var s = '[';
          var first = true;
          var pr_str = lookup('pr-str');
          for (var i = 0; i < this.count; i++) {
            if (!first) {
              s = s + ' ';
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

        PersistentVector.prototype.take = function(n) {
          if (n == 0) { return PersistentVector.EMPTY; }
          if (n == this.count) { return this; }
          return this.subvec(0, n);
        }

        def('PersistentVector', Colls.PersistentVector);
      })();

      /* PersistentArrayMap */

      (function () {
        var PersistentArrayMap = Colls.PersistentArrayMap = function (f) {
          this.h = hamt.mutate(f, hamt.make({
            hash:  lookup('hash'),
            keyEq: lookup('=')
          }));
          Object.freeze(this);
        };

        ['map?', 'collection?', 'associative?',
         'counted?', 'seqable?'].forEach(function (quality) {
          PersistentArrayMap.prototype[m(quality)] = true;
        });

        PersistentArrayMap.prototype.get = function(key) {
          return hamt.get(key, this.h);
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

        PersistentList.prototype.drop = function (n) {
          if (n == 0) { return this }
          if (n == 1) { return this.cdr }
          if (this.cdr) { return this.cdr.drop(n - 1) }
          return PersistentList.EMPTY;
        }

        PersistentList.prototype.take = function(n) {
          // this is *not* efficient. lazy-seq would help :|
          if (n == 0) { return PersistentList.EMPTY; }
          if (n == 1) { return new PersistentList(this.car, null); }
          return new PersistentList(this.car, this.cdr.take(n - 1));
        }
      })();

      /* Keyword */

      (function () {
        var Keyword = Colls.Keyword = function (name) {
          this.name = name;
          Object.freeze(this);
        };

        ['keyword?'].forEach(function (quality) {
          Keyword.prototype[m(quality)] = true;
        });
      })();

      /* Symbol */

      (function () {
        var Symbol = Colls.Symbol = function (name) {
          this.name = name;
          Object.freeze(this);
        };

        ['symbol?'].forEach(function (quality) {
          Symbol.prototype[m(quality)] = true;
        });
      })();

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
          return null; // my little pointer - null is magic.
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

      def('get', function (coll, key) {
        return coll.get(key);
      });

      def('contains?', function (coll, key) {
        return !!coll.get(key);
      });

      def('empty?', function (coll, key) {
        return coll.is_empty();
      });

      def('nth', function (coll, n) {
        return coll.nth(n);
      });

      def('last', function (coll) {
        return coll.last();
      });

      def('first', function (coll) {
        return coll.first();
      });

      def('drop', function (n, coll) {
        return coll.drop(n);
      });

      def('take', function (n, coll) {
        return coll.take(n);
      });

      def('rest', function (coll) {
        return drop(1, coll);
      });

      def('subvec', function (coll, start, end) {
        return coll.subvec(start, end);
      });

      def('reduce', function (f, z, coll) {
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
          return hamt.hash(x.name);
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

      var _ShinAtom = function (val) {
        this._value = val;
      };

      _ShinAtom.prototype.deref = function () {
        return this._value;
      }

      _ShinAtom.prototype.reset = function (val) {
        return this._value = val;
      }

      _ShinAtom.prototype.swap = function () {
        var f = arguments[0], params = [this._value];
        for (var i = 1; i < arguments.length; i++) {
          params.push(arguments[i]);
        }
        return this._value = arguments[0].apply(null, params);
      }

      def('atom', function (val) {
        return new _ShinAtom(val);
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
        return keyword.name;
      });

      def('inc', function (x) {
        return x + 1;
      })

      def('nil?', function (x) {
        return x === null;
      });

      def('truthy', function (x) {
        return x === false || x == null ? false : true;
      });

      def('falsey', function (x) {
        return !truthy(x);
      });

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
              l.count === r.count) { return true }
          var pr_str = lookup('pr-str');
          var max = l.count;
          if (r.count != max) { return false };
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
          return l.name == r.name;
        }
        if (l[m('keyword?')] && r[m('keyword?')]) {
          return l.name == r.name;
        }
        return false;
      }

      def('=', function () {
        var count = arguments.length,
            i = 1,
            lhs = arguments[0];
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

      def('pr-str', function(x) {
        var type = typeof x;
        if (type == "string") {
          return x;
        } else if (type == "number") {
          return String(x);
        } else {
          return x.printString();
        }
      });

      def('prn', function() {
        console.log.apply(console,arguments);
      });

      def('str', function() {
        return String.prototype.concat.apply('',arguments);
      });

      return core_aliases;
    })(),
  }
});

