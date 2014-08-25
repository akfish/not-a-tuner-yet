define (require, exports, module) ->
  colors = require './colors'
  console.log colors
  class KernelCache
    constructor: (@min_spread = 5, @clamp = 0.03) ->
      @cache = {}

    _calc_kernel: (alpha) ->
      sigma_square = 100.0 + alpha
      K = []
      a = 1 / Math.sqrt(2 * Math.PI * sigma_square)
      b = -1 / 2 / sigma_square
      i = 0
      while true
        k = a * Math.exp(i * i * b)
        #console.log k
        if i > @min_spread and k < @clamp
          break
        K.push k
        i++
      return K

    get: (alpha) ->
      if alpha in @cache
        return @cache[alpha]
      kernel = @_calc_kernel alpha
      @cache[alpha] = kernel
      return kernel

  class VisualizerPass
    constructor: (@v, @p) ->
      @cx = @v.outer_left + @v.outer_size / 2
      @cy = @v.outer_top + @v.outer_size / 2
      @inner_radius = @v.inner_size / 2
      @outer_radius = @v.outer_size / 2
      [@width, @height] = [@v.$el.width(), @v.$el.height()]
      @radius_limit = Math.sqrt(@width * @width + @height * @height) / 2
      @init?()
      @kernels = new KernelCache()

    draw_circle: (color, alpha, radius) ->
      if radius > @radius_limit
        #console.log radius
        return
      @p.noFill()
      @p.stroke @p.color(color, alpha)
      @p.ellipse @cx, @cy, radius * 2, radius * 2

    draw_blur_circle: (color, alpha, radius) ->
      if radius > @radius_limit
        #console.log radius
        return
      K = @kernels.get alpha
      @draw_circle color, alpha * K[0], radius
      for d in [1..K.length - 1]
        @draw_circle color, alpha * K[d], radius - d
        @draw_circle color, alpha * K[d], radius + d

    # Draw circular bin
    # @param color {Number} Color
    # @param alpha {Byte} Alpha
    # @param c {Object} (x, y, theta)
    # @param w {float} Bin width
    # @param len {float} Bin height
    draw_cirular_bin: (color, alpha, c, w, len)->
      color = @p.color color, alpha
      @p.fill color
      @p.stroke color
      @p.pushMatrix()
      @p.translate c.x, c.y
      @p.rotate Math.PI / 2 + c.t
      @p.translate -c.x, -c.y
      @p.rect c.x, c.y, w, len
      @p.popMatrix()

    draw: ->
      return

  class VolumePass extends VisualizerPass
    init: ->
      @volumes = []

    get_volume: ->
      if not @v.processor or not @v.processor.ready
        delta = (1 + @p.sin(@p.frameCount / 10)) * 10
      else
        delta = @v.processor.volume * 20
      return delta

    draw: ->
      volume = @get_volume()
      @volumes.push volume
      if @volumes.length > 255
        @volumes.shift()
      for vol, i in @volumes
        alpha = vol * i / 255
        radius = @outer_radius + vol / 2
        @draw_blur_circle colors[3], alpha, radius
        @volumes[i] = vol + 10
      @draw_circle colors[4], 255, @outer_radius + volume / 2

  class SpectrumPass extends VisualizerPass
    init: ->
      @max_bins = []
      @min_hz = 80
      @max_hz = 10000
      @max_value = 255
      @track_history = true
      @history_color = colors[3]
      @current_color = colors[0]

    get_spectrum: ->
      if not @v.processor or not @v.processor.ready
        return []
        #return _.map([0..128 - 1], (n) -> (1 + p.sin(n + p.frameCount)) / 4 * 255)
      else
        @start_bin = @v.processor.get_bin_index @min_hz
        @end_bin = @v.processor.get_bin_index @max_hz
        bins = @_do_get_spectrum()
        return _.map [@start_bin..@end_bin], (i) -> bins[i]
        #return @v.processor.frequency_bins#[start..end]

    _do_get_spectrum: ->
      return @v.processor.frequency_bins

    calculate_bin_centers: (bins, max = 255) ->
      max_len = (@v.outer_size - @v.inner_size)# / 2
      arc_step = 2 * Math.PI / bins.length
      bin_centers = []
      for bin, i in bins
        len = max_len * bin / max
        r = @inner_radius + len / 2# + max_len / 2
        theta = i * arc_step + Math.PI
        sin_t = @p.sin(theta)
        cos_t = @p.cos(theta)
        x = @cx + cos_t * r
        y = @cy + sin_t * r
        outer_x = @cx + cos_t * @outer_radius
        outer_y = @cy + sin_t * @outer_radius
        inner_x = @cx + cos_t * @inner_radius
        inner_y = @cy + sin_t * @inner_radius
        bin_centers.push
          x: x
          y: y
          outer_x: outer_x
          outer_y: outer_y
          inner_x: inner_x
          inner_y: inner_y
          t: theta
          len: len
      return bin_centers

    draw: ->
      bins = @get_spectrum()
      if bins.length == 0
        return
      if @max_bins.length != bins.length
        @max_bins = []
      centers = @calculate_bin_centers bins, @max_value

      w = @v.inner_size * Math.PI / 2 / bins.length
      for c, i in centers
        bin = bins[i]
        max_bin = @max_bins[i]
        len = c.len
        if max_bin? and max_bin.len > len and max_bin.alpha > 0
          if max_bin.len > 1 and @track_history
            @draw_cirular_bin @history_color, max_bin.alpha, max_bin.c, w, max_bin.len
          max_bin.alpha -= 1
        else
          new_max_bin =
            alpha: 100
            c: c
            len: len
          @max_bins[i] = new_max_bin
        if len > 1
          @draw_cirular_bin @current_color, 128, c, w, len

      @post_draw? bins, centers

  class HpsPass extends SpectrumPass
    init: ->
      super()
      @current_color = colors[1]
      @track_history = false
      @max_blob_radius = 32
      @init_blob_alpha = 128
      @current_blob_color = colors[0]
      @history_blob_color = colors[0]
      @blobs = []
      @max_blobs_per_index = 8
      @blob_count = {}
      @blob_recent = {}
      @max_random_movement = 20

    _do_get_spectrum: ->
      @max_value = @v.processor.HPS_MAX
      return @v.processor.HPS

    _draw_blob: (x, y, r, color, alpha) ->
      c = @p.color color, alpha
      @p.stroke c
      @p.fill c
      @p.ellipse x, y, r * 2, r * 2

    post_draw: (bins, centers) ->
      # Visulize HPS peeks
      threshold = @max_value * 0.3
      peeks = []
      for bin, i in bins
        # Hacky way to surpress 90% of low frequency peeks
        if i < 10 and Math.random() > 0.9
          continue
        if bin > threshold
          peeks.push
            bin: bin
            index: i

      # Draw them as 'blobs'
      # Old blobs first
      n = @blobs.length
      i = 0
      while i < n
        blob = @blobs.shift()
        i++
        # Discard old blobs
        if blob.alpha <= 0
          @blob_count[blob.index]--
          continue
        alpha = blob.alpha
        radius = blob.r
        # 'Punish' hotspots
        if @blob_count[blob.index] > 2
          blob.alpha /= @blob_count[blob.index]
          blob.r *= @blob_count[blob.index] * 0.3
        # draw
        @_draw_blob blob.x, blob.y, blob.r, @history_blob_color, blob.alpha
        # Update
        blob.alpha -= 1
        blob.r += 1
        if @blob_recent[blob.index] < blob.alpha
          @blob_recent[blob.index] = blob.alpha
        @blobs.push blob

      for peek in peeks
        c = centers[peek.index]
        r = @max_blob_radius * peek.bin / @max_value
        if not @blob_count[peek.index]?
          @blob_count[peek.index] = 0
        # Discard if there're too many blobs at the same spot
        if @blob_count[peek.index] > @max_blobs_per_index
          continue
        # Discard if there're recent blob
        if @init_blob_alpha - @blob_recent[peek.index] < 3 and @blob_count[peek.index] > 0
          continue
        blob =
          index: peek.index
          x: c.outer_x + Math.random() * @max_random_movement
          y: c.outer_y + Math.random() * @max_random_movement
          r: r
          alpha: @init_blob_alpha

        @blob_recent[blob.index] = @init_blob_alpha
        # 'Punish' hotspots
        if @blob_count[blob.index] > 2
          blob.alpha /= @blob_count[blob.index]
          blob.r *= @blob_count[blob.index] * 0.3
        @_draw_blob blob.x, blob.y, blob.r, @current_blob_color, blob.alpha
        @blobs.push blob
        @blob_count[peek.index]++

  class Visualizer
    make_proc: (v) ->
      (p) ->
        volume_pass = new VolumePass(v, p)
        spectrum_pass= new SpectrumPass(v, p)
        hps_pass = new HpsPass(v, p)

        p.setup = ->
          p.size v.$el.width(), v.$el.height()
          p.frameRate 60
          p.background 0, 0

        p.draw = ->
          p.background 0, 0
          p.smooth()
          volume_pass.draw()
          spectrum_pass.draw()
          hps_pass.draw()
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
