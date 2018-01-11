$ ->
  # Activate sidenav on small screens
  $(".button-collapse").sideNav()

  # This is kind of a hack to make the tabs look right on initial page load */
  $(".tabs.input-tabs .indicator").css('right', '66.66%')

  # Replace bootstrap glyphicons from wishart gem with materialize icons
  $(".wishart-link-out .glyphicon").replaceWith('<i class="tiny material-icons">open_in_new</i>')

  # Close alerts
  $(".alert button.close").click () ->
    $(this).closest(".alert").css('display', 'none')
    return

  # Activate modals
  $('.modal-trigger').leanModal()