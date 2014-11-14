
(function (root, factory) {
  if (typeof exports === 'object') {
    var oak = require('ancient-oak');
    factory(exports, oak);
  } else if (typeof define === 'function' && define.amd) {
    define(['exports', 'ancient-oak'], factory)
  } else {
    throw "No AMD loader detected, shin code can't run.";
  }
})(this, function (exports, oak) {
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

      def('oak', oak);

      def('vector', function () {
        var arr = new Array(arguments.length);
        for (var i = 0; i < arguments.length; i++) {
          arr[i] = arguments[i];
        }
        return oak(arr);
      });

      /* This is quite incorrect. */
      def('list', lookup('vector'));

      def('vec', function (arr) {
        return oak(arr);
      });

      def('hash-map', function () {
        if (arguments.length % 2 != 0) {
          throw new Exception("Odd number of elements passed to hash map");
        }
        var obj = {};
        for (var i = 0, max = arguments.length / 2; i < max; i++) {
          obj[els[(i * 2)]] = els[(i * 2) + 1];
        }
        return oak(obj);
      });

      def('nth', function (coll, index) {
        return coll(index);
      });

      def('last', function (coll) {
        return coll(coll.size - 1);
      });

      def('first', function (coll) {
        return coll(0);
      });

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
        if (l === undefined || r === undefined) { return false };
        if (l.forEach && r.forEach) {
          var eq = true;
          l.forEach(function (v, k) {
            if (!equals2(r(k), v)) { eq = false };
          })
          if (!eq) { return false };
          r.forEach(function (v, k) {
            if (!equals2(l(k), v)) { eq = false };
          })
          return eq;
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

