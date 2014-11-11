
(function (root) {
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
    exports.intern.call(self, mori);
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
  exports.modules = {
    core: {
      truthy: function(x) {
        return x === false || x == null ? false : true;
      },
      falsey: function(x) {
        return !truthy(x);
      },
      not: function(x) {
        return !truthy(x);
      },
      eq: function() { 
        return equals.apply(null,arguments); 
      },
      neq: function() {
        return !equals.apply(null,arguments); 
      },
      add: function() {
        var res = 0.0;
        for (var i=0; i<arguments.length; i++) {
          res += arguments[i];
        }
        return res;
      },
      sub: function() {
        var res = arguments[0];
        for (var i=1; i<arguments.length; i++) {
          res -= arguments[i];
        }
        return res;
      },
      mul: function() {
        var res = 1.0;
        for (var i=0; i<arguments.length; i++) {
          res *= arguments[i];
        }
        return res;
      },
      div: function() {
        var res = arguments[0];
        for (var i=1; i<arguments.length; i++) {
          res /= arguments[i];
        }
        return res;
      },
      mod: function(a,b) {
        return a % b;
      },
      lt: function() {
        var res = true;
        for (var i=0; i<arguments.length-1; i++) {
          res = res && arguments[i] < arguments[i+1];
          if (!res) break;
        }
        return res;
      },
      gt: function() {
        var res = true;
        for (var i=0; i<arguments.length-1; i++) {
          res = res && arguments[i] > arguments[i+1];
          if (!res) break;
        }
        return res;
      },
      leq: function() {
        var res = true;
        for (var i=0; i<arguments.length-1; i++) {
          res = res && arguments[i] <= arguments[i+1];
          if (!res) break;
        }
        return res;
      },
      geq: function() {
        var res = true;
        for (var i=0; i<arguments.length-1; i++) {
          res = res && arguments[i] >= arguments[i+1];
        }
        return res;
      },
      prn: function() {
        console.log.apply(console,arguments);
      },
      str: function() {
        return String.prototype.concat.apply('',arguments);
      }
    },
    mori: mori
  }
});

