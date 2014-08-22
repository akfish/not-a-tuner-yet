define (require, exports, module) ->
  console.log '-_-'

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

  $(document).ready ->
    $("#show-content").click ->
      scroll_to '#content', true
