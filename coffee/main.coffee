define (require, exports, module) ->
  console.log '-_-'
  $(document).ready ->
    $("#show-content").click ->
      $("#content").animatescroll()
