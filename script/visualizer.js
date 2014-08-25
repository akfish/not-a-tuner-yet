var __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

define(function(require, exports, module) {
  var HpsPass, KernelCache, SpectrumPass, Visualizer, VisualizerPass, VolumePass, colors;
  colors = require('./colors');
  console.log(colors);
  KernelCache = (function() {
    function KernelCache(min_spread, clamp) {
      this.min_spread = min_spread != null ? min_spread : 5;
      this.clamp = clamp != null ? clamp : 0.03;
      this.cache = {};
    }

    KernelCache.prototype._calc_kernel = function(alpha) {
      var K, a, b, i, k, sigma_square;
      sigma_square = 100.0 + alpha;
      K = [];
      a = 1 / Math.sqrt(2 * Math.PI * sigma_square);
      b = -1 / 2 / sigma_square;
      i = 0;
      while (true) {
        k = a * Math.exp(i * i * b);
        if (i > this.min_spread && k < this.clamp) {
          break;
        }
        K.push(k);
        i++;
      }
      return K;
    };

    KernelCache.prototype.get = function(alpha) {
      var kernel;
      if (__indexOf.call(this.cache, alpha) >= 0) {
        return this.cache[alpha];
      }
      kernel = this._calc_kernel(alpha);
      this.cache[alpha] = kernel;
      return kernel;
    };

    return KernelCache;

  })();
  VisualizerPass = (function() {
    function VisualizerPass(v, p) {
      var _ref;
      this.v = v;
      this.p = p;
      this.cx = this.v.outer_left + this.v.outer_size / 2;
      this.cy = this.v.outer_top + this.v.outer_size / 2;
      this.inner_radius = this.v.inner_size / 2;
      this.outer_radius = this.v.outer_size / 2;
      _ref = [this.v.$el.width(), this.v.$el.height()], this.width = _ref[0], this.height = _ref[1];
      this.radius_limit = Math.sqrt(this.width * this.width + this.height * this.height) / 2;
      if (typeof this.init === "function") {
        this.init();
      }
      this.kernels = new KernelCache();
    }

    VisualizerPass.prototype.draw_circle = function(color, alpha, radius) {
      if (radius > this.radius_limit) {
        return;
      }
      this.p.noFill();
      this.p.stroke(this.p.color(color, alpha));
      return this.p.ellipse(this.cx, this.cy, radius * 2, radius * 2);
    };

    VisualizerPass.prototype.draw_blur_circle = function(color, alpha, radius) {
      var K, d, _i, _ref, _results;
      if (radius > this.radius_limit) {
        return;
      }
      K = this.kernels.get(alpha);
      this.draw_circle(color, alpha * K[0], radius);
      _results = [];
      for (d = _i = 1, _ref = K.length - 1; 1 <= _ref ? _i <= _ref : _i >= _ref; d = 1 <= _ref ? ++_i : --_i) {
        this.draw_circle(color, alpha * K[d], radius - d);
        _results.push(this.draw_circle(color, alpha * K[d], radius + d));
      }
      return _results;
    };

    VisualizerPass.prototype.draw_cirular_bin = function(color, alpha, c, w, len) {
      color = this.p.color(color, alpha);
      this.p.fill(color);
      this.p.stroke(color);
      this.p.pushMatrix();
      this.p.translate(c.x, c.y);
      this.p.rotate(Math.PI / 2 + c.t);
      this.p.translate(-c.x, -c.y);
      this.p.rect(c.x, c.y, w, len);
      return this.p.popMatrix();
    };

    VisualizerPass.prototype.draw = function() {};

    return VisualizerPass;

  })();
  VolumePass = (function(_super) {
    __extends(VolumePass, _super);

    function VolumePass() {
      return VolumePass.__super__.constructor.apply(this, arguments);
    }

    VolumePass.prototype.init = function() {
      return this.volumes = [];
    };

    VolumePass.prototype.get_volume = function() {
      var delta;
      if (!this.v.processor || !this.v.processor.ready) {
        delta = (1 + this.p.sin(this.p.frameCount / 10)) * 10;
      } else {
        delta = this.v.processor.volume * 20;
      }
      return delta;
    };

    VolumePass.prototype.draw = function() {
      var alpha, i, radius, vol, volume, _i, _len, _ref;
      volume = this.get_volume();
      this.volumes.push(volume);
      if (this.volumes.length > 255) {
        this.volumes.shift();
      }
      _ref = this.volumes;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        vol = _ref[i];
        alpha = vol * i / 255;
        radius = this.outer_radius + vol / 2;
        this.draw_blur_circle(colors[3], alpha, radius);
        this.volumes[i] = vol + 10;
      }
      return this.draw_circle(colors[4], 255, this.outer_radius + volume / 2);
    };

    return VolumePass;

  })(VisualizerPass);
  SpectrumPass = (function(_super) {
    __extends(SpectrumPass, _super);

    function SpectrumPass() {
      return SpectrumPass.__super__.constructor.apply(this, arguments);
    }

    SpectrumPass.prototype.init = function() {
      this.max_bins = [];
      this.min_hz = 100;
      this.max_hz = 10000;
      this.max_value = 255;
      this.track_history = true;
      this.history_color = colors[3];
      this.current_color = colors[0];
      return this.angle_offset = Math.PI / 100;
    };

    SpectrumPass.prototype.get_spectrum = function() {
      var bins, _i, _ref, _ref1, _results;
      if (!this.v.processor || !this.v.processor.ready) {
        return [];
      } else {
        this.start_bin = this.v.processor.get_bin_index(this.min_hz);
        this.end_bin = this.v.processor.get_bin_index(this.max_hz);
        bins = this._do_get_spectrum();
        return _.map((function() {
          _results = [];
          for (var _i = _ref = this.start_bin, _ref1 = this.end_bin; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; _ref <= _ref1 ? _i++ : _i--){ _results.push(_i); }
          return _results;
        }).apply(this), function(i) {
          return bins[i];
        });
      }
    };

    SpectrumPass.prototype._do_get_spectrum = function() {
      return this.v.processor.frequency_bins;
    };

    SpectrumPass.prototype.calculate_bin_centers = function(bins, max, offset) {
      var arc_step, bin, bin_centers, cos_t, i, inner_x, inner_y, len, max_len, outer_x, outer_y, r, sin_t, theta, x, y, _i, _len;
      if (max == null) {
        max = 255;
      }
      if (offset == null) {
        offset = 0;
      }
      max_len = this.v.outer_size - this.v.inner_size;
      arc_step = 2 * Math.PI / bins.length;
      bin_centers = [];
      for (i = _i = 0, _len = bins.length; _i < _len; i = ++_i) {
        bin = bins[i];
        len = max_len * bin / max;
        r = this.inner_radius + len / 2;
        theta = i * arc_step + Math.PI + offset;
        sin_t = this.p.sin(theta);
        cos_t = this.p.cos(theta);
        x = this.cx + cos_t * r;
        y = this.cy + sin_t * r;
        outer_x = this.cx + cos_t * this.outer_radius;
        outer_y = this.cy + sin_t * this.outer_radius;
        inner_x = this.cx + cos_t * this.inner_radius;
        inner_y = this.cy + sin_t * this.inner_radius;
        bin_centers.push({
          x: x,
          y: y,
          outer_x: outer_x,
          outer_y: outer_y,
          inner_x: inner_x,
          inner_y: inner_y,
          t: theta,
          len: len
        });
      }
      return bin_centers;
    };

    SpectrumPass.prototype.draw = function() {
      var bin, bins, c, centers, i, len, max_bin, new_max_bin, w, _i, _len;
      bins = this.get_spectrum();
      if (bins.length === 0) {
        return;
      }
      if (this.max_bins.length !== bins.length) {
        this.max_bins = [];
      }
      centers = this.calculate_bin_centers(bins, this.max_value, this.angle_offset);
      w = this.v.inner_size * Math.PI / 2 / bins.length;
      for (i = _i = 0, _len = centers.length; _i < _len; i = ++_i) {
        c = centers[i];
        bin = bins[i];
        max_bin = this.max_bins[i];
        len = c.len;
        if ((max_bin != null) && max_bin.len > len && max_bin.alpha > 0) {
          if (max_bin.len > 1 && this.track_history) {
            this.draw_cirular_bin(this.history_color, max_bin.alpha, max_bin.c, w, max_bin.len);
          }
          max_bin.alpha -= 1;
        } else {
          new_max_bin = {
            alpha: 100,
            c: c,
            len: len
          };
          this.max_bins[i] = new_max_bin;
        }
        if (len > 1) {
          this.draw_cirular_bin(this.current_color, 128, c, w, len);
        }
      }
      return typeof this.post_draw === "function" ? this.post_draw(bins, centers) : void 0;
    };

    return SpectrumPass;

  })(VisualizerPass);
  HpsPass = (function(_super) {
    __extends(HpsPass, _super);

    function HpsPass() {
      return HpsPass.__super__.constructor.apply(this, arguments);
    }

    HpsPass.prototype.init = function() {
      HpsPass.__super__.init.call(this);
      this.current_color = colors[1];
      this.track_history = false;
      this.max_blob_radius = 32;
      this.init_blob_alpha = 128;
      this.current_blob_color = colors[0];
      this.history_blob_color = colors[0];
      this.blobs = [];
      this.max_blobs_per_index = 8;
      this.blob_count = {};
      this.blob_recent = {};
      return this.max_random_movement = 20;
    };

    HpsPass.prototype._do_get_spectrum = function() {
      this.max_value = this.v.processor.HPS_MAX;
      return this.v.processor.HPS;
    };

    HpsPass.prototype._draw_blob = function(x, y, r, color, alpha) {
      var c;
      c = this.p.color(color, alpha);
      this.p.stroke(c);
      this.p.fill(c);
      return this.p.ellipse(x, y, r * 2, r * 2);
    };

    HpsPass.prototype.post_draw = function(bins, centers) {
      var alpha, bin, blob, c, i, n, peek, peeks, r, radius, threshold, _i, _j, _len, _len1, _results;
      threshold = this.max_value * 0.3;
      peeks = [];
      for (i = _i = 0, _len = bins.length; _i < _len; i = ++_i) {
        bin = bins[i];
        if (i < 10 && Math.random() > 0.9) {
          continue;
        }
        if (bin > threshold) {
          peeks.push({
            bin: bin,
            index: i
          });
        }
      }
      n = this.blobs.length;
      i = 0;
      while (i < n) {
        blob = this.blobs.shift();
        i++;
        if (blob.alpha <= 0) {
          this.blob_count[blob.index]--;
          continue;
        }
        alpha = blob.alpha;
        radius = blob.r;
        if (this.blob_count[blob.index] > 2) {
          blob.alpha /= this.blob_count[blob.index];
          blob.r *= this.blob_count[blob.index] * 0.3;
        }
        this._draw_blob(blob.x, blob.y, blob.r, this.history_blob_color, blob.alpha);
        blob.alpha -= 1;
        blob.r += 1;
        if (this.blob_recent[blob.index] < blob.alpha) {
          this.blob_recent[blob.index] = blob.alpha;
        }
        this.blobs.push(blob);
      }
      _results = [];
      for (_j = 0, _len1 = peeks.length; _j < _len1; _j++) {
        peek = peeks[_j];
        c = centers[peek.index];
        r = this.max_blob_radius * peek.bin / this.max_value;
        if (this.blob_count[peek.index] == null) {
          this.blob_count[peek.index] = 0;
        }
        if (this.blob_count[peek.index] > this.max_blobs_per_index) {
          continue;
        }
        if (this.init_blob_alpha - this.blob_recent[peek.index] < 3 && this.blob_count[peek.index] > 0) {
          continue;
        }
        blob = {
          index: peek.index,
          x: c.outer_x + Math.random() * this.max_random_movement,
          y: c.outer_y + Math.random() * this.max_random_movement,
          r: r,
          alpha: this.init_blob_alpha
        };
        this.blob_recent[blob.index] = this.init_blob_alpha;
        if (this.blob_count[blob.index] > 2) {
          blob.alpha /= this.blob_count[blob.index];
          blob.r *= this.blob_count[blob.index] * 0.3;
        }
        this._draw_blob(blob.x, blob.y, blob.r, this.current_blob_color, blob.alpha);
        this.blobs.push(blob);
        _results.push(this.blob_count[peek.index]++);
      }
      return _results;
    };

    return HpsPass;

  })(SpectrumPass);
  Visualizer = (function() {
    Visualizer.prototype.make_proc = function(v) {
      return function(p) {
        var hps_pass, spectrum_pass, volume_pass;
        volume_pass = new VolumePass(v, p);
        spectrum_pass = new SpectrumPass(v, p);
        hps_pass = new HpsPass(v, p);
        p.setup = function() {
          p.size(v.$el.width(), v.$el.height());
          p.frameRate(60);
          return p.background(0, 0);
        };
        p.draw = function() {
          p.background(0, 0);
          p.smooth();
          volume_pass.draw();
          spectrum_pass.draw();
          return hps_pass.draw();
        };
      };
    };

    function Visualizer($el, inner_circle, outer_circle) {
      this.$el = $el;
      this.inner_circle = inner_circle;
      this.outer_circle = outer_circle;
      this.el = this.$el[0];
      this.inner_size = this.inner_circle.width();
      this.outer_size = this.outer_circle.width();
      this.inner_top = this.inner_circle.position().top;
      this.inner_left = this.inner_circle.position().left;
      this.outer_top = this.outer_circle.position().top;
      this.outer_left = this.outer_circle.position().left;
      this.processing = new Processing(this.el, this.make_proc(this));
    }

    Visualizer.prototype.bind = function(processor) {
      this.processor = processor;
    };

    return Visualizer;

  })();
  return module.exports = Visualizer;
});
