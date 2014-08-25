define (require, exports, module) ->
  default_opts =
    fft_size: 2048
    smoothing_time_const: 0.3
    buffer_size: 2048


  class Processor
    @is_valid: ->
      window.AudioContext ?= window.webkitAudioContext
      navigator.getUserMedia ?= navigator.webkitGetUserMedia
      return window.AudioContext? and navigator.getUserMedia?

    use_audio: (url, callback) ->
      @source = @context.createBufferSource()

      @source.connect @analyser
      @analyser.connect @context.destination

      xhr = new XMLHttpRequest()
      xhr.onload = =>
        that = @
        @context.decodeAudioData xhr.response, ((b) ->
          console.log "Audio loaded: #{url}, Sample rate: #{that.context.sampleRate}Hz"
          that.audio_buffer = b
          that.source.buffer = b
          that.source.loop = true
          that.source.start 0.0
          that.ready = true
          callback?()
          ), (err) ->
            console.error "Fail to load audio: #{url}"
            callback? err
      xhr.open "GET", url, true
      xhr.responseType = 'arraybuffer'
      xhr.send()

    use_mic: (callback) ->

      navigator.getUserMedia audio: true, ((stream) =>
        @source = @context.createMediaStreamSource stream

        @source.connect @analyser
        @analyser.connect @context.destination
        @ready = true
        console.log "Microphone open. Sample rate: #{@context.sampleRate} Hz"
        callback?()
      ), (err) ->
        console.error "Fail to access microphone: #{err}"
        callback? err

    _process: ->
      @frequency_bin_count = n = @analyser.frequencyBinCount
      @frequency_bins = arr = new Uint8Array(n)
      @analyser.getByteFrequencyData arr
      # Calculate volume
      @volume = _.reduce arr, ((sum, i) -> sum + i), 0
      @volume /= n
      # Calculate HPS
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
        @HPS_MAX = Math.max(value, @HPS_MAX)
        if @HPS_MAX == value
          max_i = i
        @HPS.push value

      max_hz = @context.sampleRate / n * max_i

    get_bin_index: (hz) ->
      if @frequency_bin_count == 0
        return 0
      hz_per_bin = @context.sampleRate / @frequency_bin_count
      return Math.floor hz / hz_per_bin

    constructor: (opts) ->
      opts ?= {}
      @frequency_bin_count = 0
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
