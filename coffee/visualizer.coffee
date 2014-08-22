define (require, exports, module) ->
  class Visualizer
    _proc: (p) =>
      p.draw = ->
        p.background 0, 0
      return

    constructor: (@$el) ->
      @el = @$el[0]
      @processing = new Processing(@el, @_proc)

  module.exports = Visualizer
