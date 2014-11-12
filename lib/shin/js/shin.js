
(function (root, factory) {
  if (typeof exports === 'object') {
    var mori = require('mori');
  } else if (typeof define === 'function' && define.amd) {
    define(['exports', 'mori'], factory)
  } else {
    throw "No AMD loader detected, shin code can't run.";
  }
})(this, function (exports, mori) {
  exports.init = function (self, ns_name) {
    if (exports.namespaces[ns_name] === undefined) {
      exports.namespaces[ns_name] = { vars: {} };
    }
    self._shin_ns_name = ns_name;
    self._shin_ns_ctx = self;
    exports.intern.call(self, exports.modules.core);
    exports.intern.call(self, exports.modules.mori);
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
    mori: (function() {
      var m = exports.mangle;
      var mori_aliases = {};
      Object.keys(mori).forEach(function (name) {
        var f = mori[name];

        if (/^is_(.*)$/.test(name)) {
          mori_aliases[m(RegExp.$1 + '?')] = f;
        } else if (/^(.*)_to_(.*)$/.test(name)) {
          mori_aliases[m(RegExp.$1 + "->" + RegExp.$2)] = f;
        } else if (name == "has_key") {
          mori_aliases[m("contains?")] = f;
        } else {
          mori_aliases[m(name.replace(/_/g, '-'))] = f;
        }
      });
      return mori_aliases;
    })(),
    core: (function () {
      var m = exports.mangle;
      var core_aliases = {};
      var def = function (name, f) {
        core_aliases[m(name)] = f;
      }

      def('re-matches', function (pattern, str) {
        // TODO: return a list if multiple matches, or a string if single match
        str.match(new RegExp('^' + pattern.source + '$'));
      });

      def('re-matcher', function (pattern, str) {
        return {
          _type: "shin.Matcher",
          pattern: pattern,
          str: str
        }
      });

      def('re-find', function (pattern, str) {
        if (pattern._type === "shin.Matcher") {
          var matcher = pattern;
          return matcher.pattern.exec(matcher.str.substring(matcher.pattern.lastIndex + 1));
        } else {
          return pattern.exec(str)[0];
        }
      });

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

      def('=', function (x) {
        return equals.apply(null,arguments); 
      });

      def('not=', function (x) {
        return !equals.apply(null,arguments); 
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

