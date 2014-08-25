define (require, exports, module) ->
  console.log '-_-'

  # Manage a group of elements
  # One of which can be activated
  class ElementGroup
    # Create an instance
    # @param selectors [Array] An array of jQuery selectors
    # @param default_on [String] Selector of the default active element
    # @param active_class [String] CSS class of active element. If not set, visibilities will be toggled
    constructor: (@selectors, default_on, @active_class) ->
      @$els = {}
      for sel in @selectors
        @$els[sel] = $(sel)

      @activate default_on

    activate: (sel_or_el) ->
      for sel, $el of @$els
        if sel == sel_or_el or $el == sel_or_el
          @_turn_on $el
        else
          @_turn_off $el

    _turn_on: ($el) ->
      if not @active_class?
        $el.show()
      else
        $el.toggleClass @active_class, true

    _turn_off: ($el) ->
      if not @active_class?
        $el.hide()
      else
        $el.toggleClass @active_class, false


  scroll_to = (name, set_hash = false) ->
    target = $("#{name}")
    if not target[0]?
      target = $('#visualizer')
    target.animatescroll
      onScrollEnd: ->
        if set_hash
          window.location.hash = name

  $(window).on 'hashchange', ->
    scroll_to window.location.hash

  sample_audio_url = location.pathname + "audio/playing_love.mp3"

  $(document).ready ->

    links = new ElementGroup(['#use-mic', '#use-sample'], '#use-sample', 'active')
    icons = new ElementGroup(['#play-button', '#pause-button', '#loading-icon', '#warning-icon'], '#loading-icon')
    status = $('#status')

    show_error_message = (msg) ->
      icons.activate '#warning-icon'
      status.text msg

    show_progress = (msg) ->
      icons.activate '#loading-icon'
      status.text msg

    Processor = require './processor'
    if not Processor.is_valid()
      show_error_message 'Chrome or FireFox Only'
      return

    processor = new Processor()
    #processor.use_audio location.pathname + "/audio/nocturne_with_no_moon.mp3"
    processor.use_audio sample_audio_url, (err) ->
      if err?
        show_error_message err
      else
        icons.activate '#pause-button'
        status.text 'Playing'
      $('#modes').css 'visibility', 'initial'

    $('#play-button').click ->
      icons.activate '#pause-button'
      status.text 'Playing'
      processor.resume()
    $('#pause-button').click ->
      icons.activate '#play-button'
      status.text 'Paused'
      processor.pause()

    $('#use-sample').click ->
      if $(@).hasClass 'active'
        return
      links.activate '#use-sample'
      show_progress 'Loading'

      processor.stop()
      processor.use_audio sample_audio_url, (err) ->
        if err?
          show_error_message err
          return
        icons.activate '#pause-button'
        status.text 'Playing'


    $('#use-mic').click ->
      if $(@).hasClass 'active'
        return
      links.activate '#use-mic'
      show_progress 'Waiting for user confirmation'

      processor.stop()
      processor.use_mic (err) ->
        if err?
          show_error_message err
          return
        icons.activate '#pause-button'
        status.text 'Listening'


    $("#show-content").click ->
      scroll_to '#content', true


    canvas = $("#wave canvas")
    outer_circle = $("#outer-circle")
    inner_circle = $("#inner-circle")
    Visualizer = require './visualizer'
    vis = new Visualizer(canvas, inner_circle, outer_circle)
    vis.bind processor
