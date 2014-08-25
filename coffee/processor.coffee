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

    stop: ->
      switch @mode
        when 'AUDIO'
          @source.stop()
        when 'MIC'
          @mic_stream.stop()

      @source.disconnect()
      @analyser.disconnect()

    pause: ->
      switch @mode
        when 'AUDIO' then @_pause_audio()
        when 'MIC'   then @_pause_mic()
      #@source.stop()
      #@audio_pos = context.currentTime - @start_time

    resume: ->
      switch @mode
        when 'AUDIO' then @_resume_audio()
        when 'MIC'   then @_resume_mic()
      #@source =

    _pause_audio: ->
      @source.stop()
      @audio_pos = @context.currentTime - @start_time

      @source.disconnect()
      @analyser.disconnect()

    _resume_audio: ->
      @source = @context.createBufferSource()

      @source.connect @analyser
      @analyser.connect @context.destination

      @source.buffer = @audio_buffer
      @source.loop = true
      @source.start 0.0, @audio_pos % @audio_buffer.duration
      @start_time = @context.currentTime

    _pause_mic: ->
      @stop()
      
    _resume_mic: ->
      @use_mic()

    use_audio: (url, callback) ->
      if @audio_buffer?
        @_resume_audio()
        callback?()
        return
      @source = @context.createBufferSource()

      @source.connect @analyser
      @analyser.connect @context.destination
      @mode = 'AUDIO'
      @audio_pos = 0

      xhr = new XMLHttpRequest()
      xhr.onload = =>
        that = @
        @context.decodeAudioData xhr.response, ((b) ->
          console.log "Audio loaded: #{url}, Sample rate: #{that.context.sampleRate}Hz"
          that.audio_buffer = b
          that.source.buffer = b
          that.source.loop = true
          that.source.start 0.0
          that.start_time = that.context.currentTime
          that.ready = true
          callback?()
          ), (err) ->
            console.error "Fail to load audio: #{url}"
            if not err?
              err = 'Fail to load audio'
            callback? err
            return
      xhr.open "GET", url, true
      xhr.responseType = 'arraybuffer'
      xhr.send()

    use_mic: (callback) ->
      @mode = 'MIC'
      navigator.getUserMedia audio: true, ((stream) =>
        @source = @context.createMediaStreamSource stream
        @mic_stream = stream
        @source.connect @analyser
        @analyser.connect @context.destination
        @ready = true
        console.log "Microphone open. Sample rate: #{@context.sampleRate} Hz"
        callback?()
        return
      ), (err) ->
        console.error "Fail to access microphone: #{err}"
        if not err?
          err = "Fail to access microphone"
        callback? err
        return

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
