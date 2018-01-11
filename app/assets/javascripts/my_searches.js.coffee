$ ->
  $('#my-searches').DataTable({
    "paging": true,
    "columnDefs": [ {
          "targets"  : 'no-sort',
          "orderable": false,
        }],
    "initComplete": () ->
        $('select').addClass("browser-default")
  })

  $('#remember-all').on 'click', () ->
    $('.remember-search').prop('checked', true)

  $('#remember-none').on 'click', () ->
    $('.remember-search').prop('checked', false)

  $('.remember-search, #remember-all, #remember-none').on 'click', () ->
    checked = $.map( $('.remember-search:checked'), (checked) -> checked.id )
    Cookies.set('my_searches', checked, { expires: 3650 })

  $('#remember-me').on 'click', () ->
    job_id =  $(this).data('job-id')
    remembered = Cookies.getJSON('my_searches') || []
    if $(this).prop('checked')
      if remembered.indexOf(job_id) == -1
        remembered.push(job_id)
    else 
      remembered = remembered.filter( (id) -> id != job_id )
    Cookies.set('my_searches', remembered, { expires: 3650 })

  $('.remember-my-searches').on 'click', () ->
    $('.remember-my-searches').prop('checked', $(this).prop('checked'))


