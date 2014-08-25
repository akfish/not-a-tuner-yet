define(function(require, exports, module) {
  var Processor, default_opts;
  default_opts = {
    fft_size: 2048,
    smoothing_time_const: 0.3,
    buffer_size: 2048
  };
  Processor = (function() {
    Processor.is_valid = function() {
      if (window.AudioContext == null) {
        window.AudioContext = window.webkitAudioContext;
      }
      if (navigator.getUserMedia == null) {
        navigator.getUserMedia = navigator.webkitGetUserMedia || navigator.mozGetUserMedia;
      }
      return (window.AudioContext != null) && (navigator.getUserMedia != null);
    };

    Processor.prototype.stop = function() {
      switch (this.mode) {
        case 'AUDIO':
          this.source.stop();
          break;
        case 'MIC':
          this.mic_stream.stop();
      }
      this.source.disconnect();
      return this.analyser.disconnect();
    };

    Processor.prototype.pause = function() {
      switch (this.mode) {
        case 'AUDIO':
          return this._pause_audio();
        case 'MIC':
          return this._pause_mic();
      }
    };

    Processor.prototype.resume = function() {
      switch (this.mode) {
        case 'AUDIO':
          return this._resume_audio();
        case 'MIC':
          return this._resume_mic();
      }
    };

    Processor.prototype._pause_audio = function() {
      this.source.stop();
      this.audio_pos = this.context.currentTime - this.start_time;
      this.source.disconnect();
      return this.analyser.disconnect();
    };

    Processor.prototype._resume_audio = function() {
      this.source = this.context.createBufferSource();
      this.source.connect(this.analyser);
      this.analyser.connect(this.context.destination);
      this.source.buffer = this.audio_buffer;
      this.source.loop = true;
      this.source.start(0.0, this.audio_pos % this.audio_buffer.duration);
      return this.start_time = this.context.currentTime;
    };

    Processor.prototype._pause_mic = function() {
      return this.stop();
    };

    Processor.prototype._resume_mic = function() {
      return this.use_mic();
    };

    Processor.prototype.use_audio = function(url, callback) {
      var xhr;
      if (this.audio_buffer != null) {
        this._resume_audio();
        if (typeof callback === "function") {
          callback();
        }
        return;
      }
      this.source = this.context.createBufferSource();
      this.source.connect(this.analyser);
      this.analyser.connect(this.context.destination);
      this.mode = 'AUDIO';
      this.audio_pos = 0;
      xhr = new XMLHttpRequest();
      xhr.onload = (function(_this) {
        return function() {
          var that;
          that = _this;
          return _this.context.decodeAudioData(xhr.response, (function(b) {
            console.log("Audio loaded: " + url + ", Sample rate: " + that.context.sampleRate + "Hz");
            that.audio_buffer = b;
            that.source.buffer = b;
            that.source.loop = true;
            that.source.start(0.0);
            that.start_time = that.context.currentTime;
            that.ready = true;
            return typeof callback === "function" ? callback() : void 0;
          }), function(err) {
            console.error("Fail to load audio: " + url);
            if (err == null) {
              err = 'Fail to load audio';
            }
            if (typeof callback === "function") {
              callback(err);
            }
          });
        };
      })(this);
      xhr.open("GET", url, true);
      xhr.responseType = 'arraybuffer';
      return xhr.send();
    };

    Processor.prototype.use_mic = function(callback) {
      this.mode = 'MIC';
      return navigator.getUserMedia({
        audio: true
      }, ((function(_this) {
        return function(stream) {
          _this.source = _this.context.createMediaStreamSource(stream);
          _this.mic_stream = stream;
          _this.source.connect(_this.analyser);
          _this.analyser.connect(_this.context.destination);
          _this.ready = true;
          console.log("Microphone open. Sample rate: " + _this.context.sampleRate + " Hz");
          if (typeof callback === "function") {
            callback();
          }
        };
      })(this)), function(err) {
        console.error("Fail to access microphone: " + err);
        if (err == null) {
          err = "Fail to access microphone";
        }
        if (typeof callback === "function") {
          callback(err);
        }
      });
    };

    Processor.prototype._process = function() {
      var arr, b, f, i, max_downsample, max_hz, max_i, n, value, _i, _j, _ref, _ref1;
      this.frequency_bin_count = n = this.analyser.frequencyBinCount;
      this.frequency_bins = arr = new Uint8Array(n);
      this.analyser.getByteFrequencyData(arr);
      this.volume = _.reduce(arr, (function(sum, i) {
        return sum + i;
      }), 0);
      this.volume /= n;
      this.HPS = [];
      this.HPS_MAX = 0;
      max_downsample = 5;
      max_i = 0;
      for (i = _i = 0, _ref = n - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
        if (i < 0) {
          value = 0;
        } else {
          value = i;
          for (f = _j = 2; 2 <= max_downsample ? _j <= max_downsample : _j >= max_downsample; f = 2 <= max_downsample ? ++_j : --_j) {
            b = (_ref1 = arr[i * f]) != null ? _ref1 : 0;
            value *= b;
          }
        }
        this.HPS_MAX = Math.max(value, this.HPS_MAX);
        if (this.HPS_MAX === value) {
          max_i = i;
        }
        this.HPS.push(value);
      }
      return max_hz = this.context.sampleRate / n * max_i;
    };

    Processor.prototype.get_bin_index = function(hz) {
      var hz_per_bin;
      if (this.frequency_bin_count === 0) {
        return 0;
      }
      hz_per_bin = this.context.sampleRate / this.frequency_bin_count;
      return Math.floor(hz / hz_per_bin);
    };

    function Processor(opts) {
      if (opts == null) {
        opts = {};
      }
      this.frequency_bin_count = 0;
      this.opts = _.defaults(opts, default_opts);
      this.context = new AudioContext();
      this.analyser = this.context.createAnalyser();
      this.analyser.smoothingTimeConstant = this.opts.smoothing_time_const;
      this.analyser.fftSize = this.opts.fft_size;
      this.node = this.context.createScriptProcessor(this.opts.buffer_size, 1, 1);
      this.node.onaudioprocess = this._process.bind(this);
      this.node.connect(this.context.destination);
      this.analyser.connect(this.node);
      this.ready = false;
    }

    return Processor;

  })();
  return module.exports = Processor;
});
