define (require, exports, module) ->
  default_opts =
    fft_size: 2048
    smoothing_time_const: 0.3
    buffer_size: 2048


  class Processor
    @is_valid: ->
      window.AudioContext ?= window.webkitAudioContext
      return window.AudioContext?

    use_audio: (url) ->
      @source = @context.createBufferSource()

      @source.connect @analyser
      @analyser.connect @context.destination

      xhr = new XMLHttpRequest()
      xhr.onload = =>
        that = @
        @context.decodeAudioData xhr.response, ((b) ->
          console.log "Audio loaded: #{url}"
          that.audio_buffer = b
          that.source.buffer = b
          that.source.loop = true
          that.source.start 0.0
          that.ready = true
          ), (err) ->
            console.error("Fail to load audio: #{url}")
      xhr.open "GET", url, true
      xhr.responseType = 'arraybuffer'
      xhr.send()
    use_mic: ->

    _process: ->
      @frequency_bin_count = n = @analyser.frequencyBinCount
      @frequency_bins = arr = new Uint8Array(n)
      @analyser.getByteFrequencyData arr
      # Calculate volume
      @volume = _.reduce arr, ((sum, i) -> sum + i), 0
      @volume /= n
      # Calculate HPS
      arr_2 = @_downsample arr, 2
      arr_3 = @_downsample arr, 3
      arr_4 = @_downsample arr, 4
      arr_5 = @_downsample arr, 5
      @HPS = []
      @HPS_MAX = 0
      max_downsample = 5
      max_i = 0
      for i in [0..n - 1]
        if i < 0
          value = 0
        else
          # In place down sampling
          value = i
          for f in [2..max_downsample]
            b = arr[i * f] ? 0
            value *= b
          #value = arr[i] * arr_2[i] * arr_3[i] * arr_4[i] * arr_5[i]
          #hvalue = Math.log value
        @HPS_MAX = Math.max(value, @HPS_MAX)
        if @HPS_MAX == value
          max_i = i
        @HPS.push value

      max_hz = @context.sampleRate / n * max_i
      if max_hz < 4400
        document.title = "Peak: #{max_hz} Hz"

    _downsample: (N, factor) ->
      n = N.length
      D = new Uint8Array(n)
      i = 0
      j = 0
      while i < n
        sum = 0
        count = 0
        for d in [0..factor]
          e = N[i + d] ? 0
          sum += e
          count++
          i++
        D[j] = sum / count
        j++
      # while j < n
      #   D[j] = 1
      #   j++

      return D

    constructor: (opts) ->
      console.log @_downsample [0..10], 2
      console.log @_downsample [0..10], 3
      console.log @_downsample [0..10], 4
      console.log @_downsample [0..10], 5
      opts ?= {}
      @opts = _.defaults opts, default_opts
      @context = new AudioContext()
      @analyser = @context.createAnalyser()
      @analyser.smoothingTimeConstant = @opts.smoothing_time_const
      @analyser.fftSize = @opts.fft_size

      @node = @context.createScriptProcessor @opts.buffer_size, 1, 1
      @node.onaudioprocess = @_process.bind(@)
      @node.connect @context.destination
      @analyser.connect @node

      @ready = false

  module.exports = Processor
