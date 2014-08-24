define (require, exports, module) ->
  default_opts =
    fft_size: 1024
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
      @volume = _.reduce arr, ((sum, i) -> sum + i), 0
      @volume /= n

    constructor: (opts) ->
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
