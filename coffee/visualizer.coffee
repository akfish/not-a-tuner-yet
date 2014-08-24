define (require, exports, module) ->
  colors = require './colors'
  console.log colors
  class Visualizer
    make_proc: (v) ->
      (p) ->
        volumes = []
        get_volume = ->
          if not v.processor or not v.processor.ready
            delta = (1 + p.sin(p.frameCount / 10)) * 10
          else
            delta = v.processor.volume * 20
          return delta

        get_spectrum = ->
          if not v.processor or not v.processor.ready
            return []
            #return _.map([0..128 - 1], (n) -> (1 + p.sin(n + p.frameCount)) / 4 * 255)
          else
            return v.processor.frequency_bins

        draw_circle = (color, alpha, delta) ->
          p.noFill()
          p.stroke p.color(color, alpha)
          p.ellipse v.outer_left + v.outer_size / 2,
            v.outer_top + v.outer_size / 2,
            v.outer_size + delta, v.outer_size + delta

        calculate_bin_centers = (bins) ->
          # Cached
          cx = v.inner_left + v.inner_size / 2
          cy = v.inner_top + v.inner_size / 2
          base_radius = v.inner_size / 2
          max_len = (v.outer_size - v.inner_size)# / 2
          arc_step = Math.PI / bins.length
          bin_centers = []
          for bin, i in bins
            len = max_len * bin / 255
            r = base_radius + len / 2# + max_len / 2
            theta = i * arc_step + Math.PI
            x = cx + p.cos(theta) * r
            y = cy + p.sin(theta) * r
            bin_centers.push
              x: x
              y: y
              t: theta
          return bin_centers

        visualize_volume = ->
          volume = get_volume()
          volumes.push volume
          if volumes.length > 255
            volumes.shift()
          for vol, i in volumes
            draw_circle colors[0], i * 0.1, vol
          draw_circle colors[4], 255, volume

        draw_cirular_bin = (color, alpha, c, w, len)->
          color = p.color color, alpha
          p.fill color
          p.stroke color
          p.pushMatrix()
          p.translate c.x, c.y
          p.rotate Math.PI / 2 + c.t
          p.translate -c.x, -c.y
          p.rect c.x, c.y, w, len
          p.popMatrix()

        max_bins = null
        visualize_spectrum = ->
          bins = get_spectrum()
          if bins.length == 0
            return
          if not max_bins? or max_bins.length != bins.length
            console.log "Init max_bins"
            max_bins = []
          centers = calculate_bin_centers bins
          max_len = (v.outer_size - v.inner_size) / 2
          w = v.inner_size * Math.PI / 2 / bins.length
          cx = v.inner_left + v.inner_size / 2
          cy = v.inner_top + v.inner_size / 2

          color = p.color colors[0], 128#i / bins.length * 255
          p.fill color
          p.stroke color
          for c, i in centers
            bin = bins[i]
            max_bin = max_bins[i]
            len = max_len / 255 * bin
            #console.log max_bin
            if max_bin? and max_bin.len > len and max_bin.alpha > 0
              #if max_bin.len > 1
              draw_cirular_bin colors[3], max_bin.alpha, max_bin.c, w, max_bin.len
              max_bin.alpha -= 1
            else
              new_max_bin =
                alpha: 100
                c: c
                len: len
              max_bins[i] = new_max_bin
              #console.log new_max_bin
            if len > 1
              draw_cirular_bin colors[0], 128, c, w, len

        p.setup = ->
          p.size v.$el.width(), v.$el.height()
          p.frameRate 60
          p.background 0, 0

        p.draw = ->
          p.background 0, 0
          p.smooth()
          visualize_volume()
          visualize_spectrum()
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
