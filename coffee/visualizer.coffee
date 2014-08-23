define (require, exports, module) ->
  colors = require './colors'
  console.log colors
  class Visualizer
    make_proc: (v) ->
      (p) ->
        volumes = []
        get_volume = ->
          if not v.processor
            delta = (1 + p.sin(p.frameCount / 10)) * 10
          else
            delta = v.processor.volume * 20
          return delta

        draw_circle = (color, alpha, delta) ->
          p.noFill()
          p.stroke p.color(color, alpha)
          p.ellipse v.outer_left + v.outer_size / 2,
            v.outer_top + v.outer_size / 2,
            v.outer_size + delta, v.outer_size + delta

        p.setup = ->
          p.size v.$el.width(), v.$el.height()
          p.frameRate 60
          p.background 0, 0
        p.draw = ->
          p.background 0, 0
          p.smooth()
          volume = get_volume()
          volumes.push volume
          if volumes.length > 255
            volumes.shift()
          for vol, i in volumes
            draw_circle colors[0], i * 0.1, vol
          draw_circle colors[4], 255, volume
          p.noFill()
        return

    constructor: (@$el, @inner_circle, @outer_circle) ->
      @el = @$el[0]
      @inner_size = @inner_circle.width()
      @outer_size = @outer_circle.width()
      @inner_top = @inner_circle.position().top
      @inner_left = @inner_circle.position().left
      @outer_top = @outer_circle.position().top
      @outer_left = @outer_circle.position().left
      @processing = new Processing(@el, @make_proc(@))

    bind: (@processor) ->
      #@processor.on_update ->
        # TODO: do stuff
        return
  module.exports = Visualizer
