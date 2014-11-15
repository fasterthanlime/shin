
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

      /* Vector */

      (function () {
        var Vector = Colls.Vector = function (f) {
          this.h = hamt.mutate(f, hamt.make());
        };

        ['vector?', 'collection?', 'sequential?',
         'associative?', 'counted?', 'indexed?',
         'reduceable?', 'seqable?', 'reversible?'].forEach(function (quality) {
          Vector.prototype[m(quality)] = true;
        });

        Vector.prototype.nth = function(n) {
          return hamt.get(n, this.h);
        }

        Vector.prototype.first = function() {
          return hamt.get(0, this.h);
        }

        Vector.prototype.last = function() {
          return hamt.get(hamt.count(this.h) - 1, this.h);
        }

        def('Vector', Colls.Vector);
      })();

      /* List */

      (function () {
        var List = Colls.List = function (car, cdr) {
          this.car = car;
          this.cdr = cdr;
          Object.freeze(this);
        };

        ['list?', 'seq?', 'collection?', 'sequential?',
         'counted?', 'reduceable?', 'seqable?'].forEach(function (quality) {
          List.prototype[m(quality)] = true;
        });

        List.prototype.first = function () {
          return this.car;
        }

        List.prototype.last = function () {
          if (this.cdr) {
            return this.cdr.last();
          } else {
            return this.car;
          }
        }

        List.prototype.nth = function(n) {
          if (n == 0) {
            return this.car;
          } else if (this.cdr) {
            return this.cdr.nth(n - 1);
          } else {
            throw "index out of bounds";
          }
        }
      })();

      def('vector', function () {
        var args = arguments;
        return (new Colls.Vector(function(h) {
          for (var i = 0; i < args.length; i++) {
            hamt.set(i, args[i], h);
          }
        }));
      });

      def('vec', function (coll) {
        if (coll instanceof Array) {
          return (new Colls.Vector(function(h) {
            for (var i = 0; i < coll.length; i++) {
              hamt.set(i, coll[i], h);
            }
          }));
        } else {
          throw "vecs of non-arrays: stub";
        }
      });

      def('hash-map', function () {
        var args = arguments;
        if (args.length % 2 != 0) {
          throw "Odd number of elements passed to hash-map";
        }
        throw "hash-map: stub";
        return hamt.mutate(function(h) {
          for (var i = 0, max = args.length / 2; i < max; i++) {
            hamt.set(args[(i * 2)], args[(i * 2) + 1], h);
          }
        }, hamt.make());
      });

      def('list', function recur () {
        if (arguments.length == 0) {
          return null; // my little pointer - null is magic.
        }

        var car = arguments[0], cdr = null;
        if (arguments.length > 1) {
          cdr = recur.apply(null, Array.prototype.slice.call(arguments, 1));
        }
        return new Colls.List(car, cdr); 
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
          var max = hamt.count(l.h);
          if (hamt.count(r.h) != max) { return false };
          for (var i = 0; i < max; i++) {
            if (!equals2(hamt.get(i, l.h), hamt.get(i, r.h))) { return false }
          }
          return true
        }
        return false
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

