define (require, exports, module) ->
  colors = require './colors'
  console.log colors
  class Visualizer
    make_proc: (v) ->
      (p) ->
        p.setup = ->
          p.size v.$el.width(), v.$el.height()
          p.frameRate 60
          p.background 0, 0
        p.draw = ->
          p.background 0, 0
          delta = p.sin(p.frameCount / 10) * 10
          p.noFill()
          p.stroke colors[4]
          p.ellipse v.outer_left + v.outer_size / 2,
            v.outer_top + v.outer_size / 2,
            v.outer_size + delta, v.outer_size + delta
          #p.ellipse v.outer_radius, v.outer_radius, 2 * v.outer_radius
          #p.ellipse 0, 0, 2 * v.inner_radius
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

  module.exports = Visualizer
