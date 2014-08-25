define(function(require, exports, module) {
  var ElementGroup, sample_audio_url, scroll_to;
  console.log('-_-');
  ElementGroup = (function() {
    function ElementGroup(selectors, default_on, active_class) {
      var sel, _i, _len, _ref;
      this.selectors = selectors;
      this.active_class = active_class;
      this.$els = {};
      _ref = this.selectors;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        sel = _ref[_i];
        this.$els[sel] = $(sel);
      }
      this.activate(default_on);
    }

    ElementGroup.prototype.activate = function(sel_or_el) {
      var $el, sel, _ref, _results;
      _ref = this.$els;
      _results = [];
      for (sel in _ref) {
        $el = _ref[sel];
        if (sel === sel_or_el || $el === sel_or_el) {
          _results.push(this._turn_on($el));
        } else {
          _results.push(this._turn_off($el));
        }
      }
      return _results;
    };

    ElementGroup.prototype._turn_on = function($el) {
      if (this.active_class == null) {
        return $el.show();
      } else {
        return $el.toggleClass(this.active_class, true);
      }
    };

    ElementGroup.prototype._turn_off = function($el) {
      if (this.active_class == null) {
        return $el.hide();
      } else {
        return $el.toggleClass(this.active_class, false);
      }
    };

    return ElementGroup;

  })();
  scroll_to = function(name, set_hash) {
    var target;
    if (set_hash == null) {
      set_hash = false;
    }
    target = $("" + name);
    if (target[0] == null) {
      target = $('#visualizer');
    }
    return target.animatescroll({
      onScrollEnd: function() {
        if (set_hash) {
          return window.location.hash = name;
        }
      }
    });
  };
  $(window).on('hashchange', function() {
    return scroll_to(window.location.hash);
  });
  sample_audio_url = location.pathname + "audio/playing_love.mp3";
  return $(document).ready(function() {
    var Processor, Visualizer, canvas, icons, inner_circle, links, outer_circle, processor, show_error_message, show_progress, status, vis;
    links = new ElementGroup(['#use-mic', '#use-sample'], '#use-sample', 'active');
    icons = new ElementGroup(['#play-button', '#pause-button', '#loading-icon', '#warning-icon'], '#loading-icon');
    status = $('#status');
    show_error_message = function(msg) {
      icons.activate('#warning-icon');
      return status.text(msg);
    };
    show_progress = function(msg) {
      icons.activate('#loading-icon');
      return status.text(msg);
    };
    Processor = require('./processor');
    if (!Processor.is_valid()) {
      show_error_message('Chrome or FireFox Only');
      return;
    }
    processor = new Processor();
    processor.use_audio(sample_audio_url, function(err) {
      if (err != null) {
        show_error_message(err);
      } else {
        icons.activate('#pause-button');
        status.text('Playing');
      }
      return $('#modes').css('visibility', 'initial');
    });
    $('#play-button').click(function() {
      icons.activate('#pause-button');
      status.text('Playing');
      return processor.resume();
    });
    $('#pause-button').click(function() {
      icons.activate('#play-button');
      status.text('Paused');
      return processor.pause();
    });
    $('#use-sample').click(function() {
      if ($(this).hasClass('active')) {
        return;
      }
      links.activate('#use-sample');
      show_progress('Loading');
      processor.stop();
      return processor.use_audio(sample_audio_url, function(err) {
        if (err != null) {
          show_error_message(err);
          return;
        }
        icons.activate('#pause-button');
        return status.text('Playing');
      });
    });
    $('#use-mic').click(function() {
      if ($(this).hasClass('active')) {
        return;
      }
      links.activate('#use-mic');
      show_progress('Waiting for user confirmation');
      processor.stop();
      return processor.use_mic(function(err) {
        if (err != null) {
          show_error_message(err);
          return;
        }
        icons.activate('#pause-button');
        return status.text('Listening');
      });
    });
    $("#show-content").click(function() {
      return scroll_to('#content', true);
    });
    canvas = $("#wave canvas");
    outer_circle = $("#outer-circle");
    inner_circle = $("#inner-circle");
    Visualizer = require('./visualizer');
    vis = new Visualizer(canvas, inner_circle, outer_circle);
    return vis.bind(processor);
  });
});
