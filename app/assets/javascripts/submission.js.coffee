# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

$ ->
  if $('#phaster-status').length > 0
    setTimeout(updateStatus, 5000)

  # When the example button is clicked, populate the accession form with
  # the value stored in the button and submit the form
  $('button.example-btn').click ->
    $("#accession-form #identifier").val($(this).attr("example"))
    $("#accession-form").submit()

  # Show progress bars after form submit for accession and sequence forms
  $('#accession-form button[type="submit"], #sequence-form button[type="submit"]').click () ->
    form_tab = $(this).closest(".tab-content")
    # Only show the progress bars if all the required fields are filled
    if $(form_tab).find("input[required], textarea[required]").val() != ""
      $(form_tab).find("input[required], textarea[required]").removeClass("required-input")
      hideButtons(form_tab)
    # Otherwise highlight the required fields
    else
      $(form_tab).find("input[required], textarea[required]").addClass("required-input")


  # Active jquery-fileupload for file form
  file_form = $('#file-form')
  file_form_tab = file_form.closest(".tab-content")
  file_form.fileupload({
    dataType: 'script',
    # maxFileSize: 12000000,
    add: (e, data) ->
      # This is a hacky bit to put the file name in the text field
      # (because for some reason jquery-fileupload overrides this)
      # it works as long as we are always uploading a single file
      $('#sequence-file-path').val(data.files[0]["name"])

      # This is a special bit to override default behaviour and wait
      # until submit button is clicked to start upload
      # Only submit if a file name is present
   
      $("#file-submit").off('click').click () ->
        if data.files[0]["size"] > 40000000
          alert('File exceeds maximum size limit. File must be less than 40MB!')
          $(file_form).find("input[required]").addClass("required-input")
        
        else if $(file_form).find("input[required]").val() != "" 
          $(file_form).find("input[required]").removeClass("required-input")
          data.submit()
        else
          $(file_form).find("input[required]").addClass("required-input")

      # Empty file input field on reset
      $("#file-reset").click () ->
        data.abort()
        data.files.length = 0
        data.originalFiles.length = 0
        $('#sequence-file-path').val("")
        $('#contigs').prop("checked", false)
        $(file_form).find("input[required]").removeClass("required-input")
  })

  # Make the submit button work even if we haven't added a file,
  # in this case the form submits "normally", i.e. without jquery-fileupload
  $("#file-submit").unbind('click').click () ->
    # Only submit if all the required fields are filled
    if $(file_form).find("input[required]").val() != ""
      $(file_form).find("input[required]").removeClass("required-input")
      file_form.submit()
    # Otherwise highlight the required fields
    else
      $(file_form).find("input[required]").addClass("required-input")

  file_form.on('fileuploadsubmit', (e, data) ->
    # Gotta add in the other form info on submit
    data.formData = {
                      'submission[category]': $('#submission_category').val(),
                      'contigs': (($('#contigs').prop('checked') == true) ? 1 : 0),
                      'get_cache': (($('#get-cache-1').prop('checked') == true) ? 1 : 0),
                      'remember_search': (($('#remember-search-1').prop('checked') == true) ? 1 : 0)
                    }
  )

  # Hide form buttons on submit
  file_form.on('fileuploadstart', () ->
    hideButtons(file_form_tab)
  )

  # When the upload is complete, redirect to the status page
  file_form.on('fileuploaddone', () ->
    # Show buttons and hide progress again, just so it looks right if "Back" is used
    resetButtons(file_form_tab)
    # Redirect to status page, this variable is set in view/submissions/create.js.erb
    window.location.href = window.redirect
  )

  # Track upload in progress bar
  progress_bar = file_form_tab.find('.progress .determinate')
  file_form.on('fileuploadprogressall', (e, data) ->
    progress = parseInt(data.loaded / data.total * 100, 10)
    progress_bar.css('width', progress + '%')
    # Once the file has uploaded, we show the "Parsing Data" indeterminate indicator
    # while the file is processed and saved
    if progress >= 100
      $(file_form_tab).find(".form_buttons .submission-indicator").css("display", "none")
      $(file_form_tab).find(".form_buttons .second-submission-indicator").css("display", "inline-block")
  )

hideButtons = (form_tab) ->
  $(form_tab).find(".form_buttons .submission-indicator").css("display", "inline-block")
  $(form_tab).find(".form_buttons button").hide()
  $(form_tab).find(".form_buttons .or").hide()

resetButtons = (form_tab) ->
  $(form_tab).find(".form_buttons .submission-indicator").css("display", "none")
  $(form_tab).find(".form_buttons .second-submission-indicator").css("display", "none")
  $(form_tab).find(".form_buttons button").show()
  $(form_tab).find(".form_buttons .or").show()

updateStatus = () ->
  job_id = $('#phaster-status').data('job-id')
  $.getScript('/submissions/' + job_id + '/status.js')
  setTimeout(updateStatus, 5000)


