$ ->
  # Scale down the plasmid label numbers if necessary
  $(".sml, .blabel").each () ->
    val = parseInt($(this).html())
    if val >= 1000000
      $(this).html((val / 1000000).toFixed(2) + "M")
    else if val >= 1000
      $(this).html((val / 1000).toFixed(0) + "K")

  # Hide/Show display options
  $(".region_line").css("visibility", "hidden")

  $("#plasmid-legend #toggle_labels").click () ->
    if /^Hide/.test($(this).html())
      $(this).html("Show Region Labels")
      selected_marker = $(".selected_marker")
      if selected_marker.length > 0
        $("g:not([region='" + $(selected_marker).attr("id") + "']) > .mlabel").css("visibility", "hidden")
      else
        $(".mlabel").css("visibility", "hidden")
    else
      $(this).html("Hide Region Labels")
      $(".mlabel").css("visibility", "visible")
    return

  $("#plasmid-legend #toggle_lines").click () ->
    if /^Hide/.test($(this).html())
      $(this).html("Show Label Lines")
      $(".region_line").css("visibility", "hidden")
    else
      $(this).html("Hide Label Lines")
      $(".region_line").css("visibility", "visible")
    return

  $("#plasmid-legend #toggle_markers").click () ->
    if /^Hide/.test($(this).html())
      $(this).html("Show Markers")
      selected_marker = $(".selected_marker")
      if selected_marker.length > 0
        $("g:not([region='" + $(selected_marker).attr("id") + "']) > .border_line").css("visibility", "hidden")
        $("g:not([region='" + $(selected_marker).attr("id") + "']) > .blabel").css("visibility", "hidden")
      else
        $(".blabel, .border_line").css("visibility", "hidden")
    else
      $(this).html("Hide Markers")
      $(".blabel, .border_line").css("visibility", "visible")
    return

  $("#plasmid-legend #toggle_sizes").click () ->
    if /^Condense/.test($(this).html())
      $(this).html("Expand Labels")
      $(".mlabel").each () ->
        text = $(this).html()
        $(this).html(text.replace("Region ", ""))
      $(".blabel").css("font-size", "8px")
    else
      $(this).html("Condense Labels")
      $(".mlabel").each () ->
        text = $(this).html()
        $(this).html("Region " + text)
      $(".blabel").css("font-size", "10px")
    return

  # Show corresponding data when hovering over prophage regions
  $("#plasmid-box").on 'mouseenter', ".marker, .mlabel", () ->
    # Hover indicator
    marker = find_marker(this)
    if !d3.select(marker).classed("selected_marker")
      highlight(marker)

  $("#plasmid-box").on 'mouseleave', ".marker, .mlabel", () ->
    marker = find_marker(this)
    if !d3.select(marker).classed("selected_marker")
      unhighlight(marker)

  # Display corresponding data in linear view when marker is clicked
  $("#plasmid-box").on 'click', ".marker, .mlabel", () ->
    marker = find_marker(this)
    # If this marker is not currently selected
    if !d3.select(marker).classed("selected_marker")
      highlight(marker)

       # Remove any other selected
      d3.selectAll(".marker.selected_marker")
        .each((data, i) ->
          unhighlight(this)
          $("#linear_viewer.linear_combined .linear_chart#" + $(this).attr("id")).hide()
          d3.select(this).classed("selected_marker", false)
        )

      d3.select(marker).classed("selected_marker", true)

      # Load data from .plasmid-info
      data = $("#plasmid-info").data("info")[$(marker).attr("id")]
      $("#plasmid-info").html("<div class='header " + data["completeness"] + "_header'>Prophage Region " + data["number"] + "</div>" +
                          "<b>Start:</b> " + data["start"] + "</br>" +
                          "<b>End:</b> " + data["end"] + "</br>" +
                          "<b># CDS:</b> " + data["sequences"].length + "</br>" +
                          "<b>Predicted Type:</b> " + data["completeness"] + "</br>" +
                          "<b>GC%:</b> " + data["gc"]
                          )

      # Show linear view
      $("#linear_viewer.linear_combined #linear_placeholder").hide()
      $("#linear_viewer.linear_combined #linear_name").html("Showing detail of Region " + data["number"]).show()
      $("#linear_viewer.linear_combined .linear_chart#" + $(marker).attr("id")).show()
    else
      d3.select(marker).classed("selected_marker", false)

      # Hide linear view
      $("#linear_viewer.linear_combined #linear_placeholder").show()
      $("#linear_viewer.linear_combined #linear_name").hide()
      $("#linear_viewer.linear_combined .linear_chart#" + $(marker).attr("id")).hide()

      $("#plasmid-info").html("Click on a region to see details.")

  # Link to save image
  $("#plasmid-legend #save_image").click () ->
    if $('#circular_genome').length > 0
      saveSvgAsPng(document.getElementById("circular_genome"), "circular_genome.png", { backgroundColor: '#ffffff' })
    else
      saveSvgAsPng(document.getElementById("contig_genome"), "contigs.png", { backgroundColor: '#ffffff' })

  # $("#plasmid-legend #save_image").click () -> 
  #   submit_download_form("circular_genome", "svg", "circular_genome")

highlight = (element) ->
  if /^Show/.test($("#plasmid-legend #toggle_labels").html())
    $("g[region='" + $(element).attr("id") + "'] > .mlabel").css("visibility", "visible")
  if /^Show/.test($("#plasmid-legend #toggle_markers").html())
    $("g[region='" + $(element).attr("id") + "'] > .border_line").css("visibility", "visible")
    $("g[region='" + $(element).attr("id") + "'] > .blabel").css("visibility", "visible")
  $(element).css("stroke", "#303f9f")
  $(element).css("stroke-width", "2px")
  $(element).parent().find(".region_line").css("stroke", "#303f9f")
  $(element).parent().find(".region_line").css("stroke-width", "2px")
  $(element).parent().find(".mlabel").css("fill", "#303f9f")

unhighlight = (element) ->
  if /^Show/.test($("#plasmid-legend #toggle_labels").html())
    $("g[region='" + $(element).attr("id") + "'] > .mlabel").css("visibility", "hidden")
  if /^Show/.test($("#plasmid-legend #toggle_markers").html())
    $("g[region='" + $(element).attr("id") + "'] > .border_line").css("visibility", "hidden")
    $("g[region='" + $(element).attr("id") + "'] > .blabel").css("visibility", "hidden")
  $(element).css("stroke", "none")
  $(element).parent().find(".region_line").css("stroke", "")
  $(element).parent().find(".region_line").css("stroke-width", "")
  $(element).parent().find(".mlabel").css("fill", "")

find_marker = (element) ->
  if $(element).hasClass('marker')
    element
  else if $(element).parent().find('.marker').length
    $(element).parent().find('.marker').get(0)
  else if $(element).parent().parent().find('.marker').length
    $(element).parent().parent().find('.marker').get(0)
  else
    undefined

window.fm = find_marker
