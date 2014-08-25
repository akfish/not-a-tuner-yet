define(function(require, exports, module) {
  var scroll_to;
  console.log('-_-');
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
  return $(document).ready(function() {
    var Processor, Visualizer, canvas, inner_circle, outer_circle, processor, vis;
    Processor = require('./processor');
    console.log(Processor.is_valid());
    processor = new Processor();
    processor.use_audio("/audio/playing_love.mp3");
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
