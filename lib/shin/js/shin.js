
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
    var def = function (name, f) {
      exports[m(name)] = f;
    }
    var lookup = function (name) {
      return exports[m(name)];
    }

    /* Data structures */ 

    def('hamt', hamt);

    var Colls = {};

    /* PersistentVector */

    (function () {
      var PersistentVector = Colls.PersistentVector = function (arg, offset, count) {
        if (typeof arg === 'function') {
          var f = arg;
          var h = offset;
          this.h = hamt.mutate(f, h ? h : hamt.make({
            hash:  lookup('hash'),
            keyEq: lookup('=')
          }));
          this.offset = 0;
          this._count = hamt.count(this.h);
        } else {
          this.h = arg;
          this.offset = offset;
          this._count = count;
        }
        Object.freeze(this);
      };
      PersistentVector.prototype._protocols = [];
      PersistentVector.EMPTY = new PersistentVector(function () {});

      ['vector?', 'collection?', 'sequential?',
      'associative?', 'counted?', 'indexed?',
      'reduceable?', 'seqable?', 'reversible?'].forEach(function (quality) {
        PersistentVector.prototype[m(quality)] = true;
      });

      PersistentVector.prototype.call = function(_, n) {
        return this.get(n);
      }

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
      
      PersistentVector.prototype.$_count = function() {
        return this._count;
      }

      PersistentVector.prototype.cons = function (x) {
        // FIXME: this is godawful.
        var self = this;
        return new PersistentVector(function (h) {
          hamt.set(0, x, h);
          for (var i = 0; i < self._count; i++) {
            hamt.set(i + 1, self.nth(i), h);
          }
        });
      }

      PersistentVector.prototype.conj = function (x) {
        // FIXME: this is godawful.
        var self = this;
        return new PersistentVector(function (h) {
          for (var i = 0; i < self._count; i++) {
            hamt.set(i, self.nth(i), h);
          }
          hamt.set(self._count, x, h);
        });
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

      PersistentVector.prototype[m('-equiv')] = function (_, other) {
        // FIXME: wholly incorrect, one can compare vectors with lists and such.
        if (!other instanceof PersistentVector) { return false }
        if (this.h === other.h &&
            this.offset === other.offset &&
            this._count === other._count) { return true }
        var max = this._count;
        if (other._count != max) { return false }

        var eq = lookup('=');
        for (var i = 0; i < max; i++) {
          if (!eq(this.nth(i), other.nth(i))) { return false }
        }
        return true
      }

      PersistentVector.prototype[m('-pr-str')] = function () {
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

      PersistentVector.prototype[m('-clj->js')] = function () {
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
        this.h = hamt.mutate(f, h ? h : hamt.make({
          hash:  lookup('hash'),
          keyEq: lookup('=')
        }));
        Object.freeze(this);
      };
      PersistentArrayMap.prototype._protocols = [];

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

      // FIXME: shouldn't exist
      PersistentArrayMap.prototype.pairs = function () {
        var v = lookup('vector');
        var ps = hamt.pairs(this.h);
        var pvs = Array(ps.length);
        for (var i = 0; i < ps.length; i++) {
          var p = ps[i];
          var pv = v(p[0], p[1]);
          pvs[i] = pv;
        }
        return v.apply(null, pvs);
      }

      PersistentArrayMap.prototype.call = function(_, n) {
        return this.get(n);
      }

      PersistentArrayMap.prototype.get = function(key) {
        return hamt.get(key, this.h);
      }

      PersistentArrayMap.prototype[m('-equiv')] = function (_, other) {
        // FIXME: wrong - should be protocol-based or something.
        if (!(other instanceof PersistentArrayMap)) { return false }

        var eq = lookup('=');
        var l = this, r = other;
        var kl = hamt.keys(l.h), kr = hamt.keys(r.h);
        if (kl.length != kr.length) { return false };
        // inefficient, I know! but least has shortcut evaluation.
        for (var i = 0; i < kl.length; i++) {
          if (!eq(hamt.get(kl[i], l.h), hamt.get(kl[i], r.h))) {
            return false;
          }
          if (!eq(hamt.get(kr[i], l.h), hamt.get(kr[i], r.h))) {
            return false;
          }
        }
        return true;
      }

      PersistentArrayMap.prototype[m('-pr-str')] = function () {
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

      PersistentArrayMap.prototype[m('-clj->js')] = function () {
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
      PersistentList.prototype._protocols = [];

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

    PersistentList.prototype.$_count = function() {
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

    PersistentList.prototype[m('-equiv')] = function (_, other) {
      var is_list = lookup('list?'), eq = lookup('='),
          first = exports.first, rest = exports.rest;

      if (!is_list(other)) { return false }
      if (!eq(first(this), first(other))) { return false }
      return eq(rest(this), rest(other));
    }

    PersistentList.prototype[m('-pr-str')] = function () {
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

    PersistentList.prototype[m('-clj->js')] = function () {
      var r = [];
      var toJS = lookup('clj->js');
      for (var c = this; c; c = c.cdr) {
        r.push(toJS(c.car));
      }
      return r;
    }

    def('PersistentList', Colls.PersistentList);

    })();

    /* End collections / types */

    ['list?', 'seq?', 'vector?', 'map?', 'set?',
      'collection?', 'sequential?', 'associative?',
      'counted?', 'indexed?', 'reduceable?',
      'seqable?', 'reversible?'].forEach(function (quality) {
        def(quality, function (coll) {
          return !!coll[m(quality)];
        });
      })
  })();
});

