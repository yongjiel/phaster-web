$ ->

  # Let's draw some genomes!

  # Default (Condensed) sizes
  height = 300
  width = 1000

  # Expanded sizes
  long_width = 2000
  bar_height = 40

  # Abbrevations for proteins types, corresponds to terms used in the results
  abbrevs = {
    lysis_protein: "Lys",
    terminase: "Ter",
    portal_protein: "Por",
    protease: "Pro",
    head_protein: "Coa",
    tail_protein: "Sha",
    attachment_site: "Att",
    integrase: "Int",
    phage_like_protein: "PLP",
    hypothetical_protein: "Hyp",
    non_phage_like_protein: "Oth",
    transposase: "Tra",
    fiber_protein: "Fib",
    plate_protein: "Pla",
    trna: "RNA"
  }

  # Draw one for each region
  $(".linear_box").each () ->
    drawLinear(this, height, width, bar_height, abbrevs)

  $(".linear_options #next-region").click () ->
    selected_marker = $('.marker.selected_marker').first()
    if selected_marker.length
      selected_region_id = selected_marker.attr('id').replace('region_', '')
      next_region_id = Number(selected_region_id) + 1
      max_regions = $('.marker').length
      if next_region_id > max_regions
        next_region_id = 1
      $('#region_' + next_region_id ).click()

  $(".linear_options #prev-region").click () ->
    selected_marker = $('.marker.selected_marker').first()
    if selected_marker.length
      selected_region_id = selected_marker.attr('id').replace('region_', '')
      prev_region_id = Number(selected_region_id) - 1
      max_regions = $('.marker').length
      if prev_region_id == 0
        prev_region_id = max_regions
      $('#region_' + prev_region_id ).click()


  # Expand/Condense options
  $(".linear_options #expand_genome").click () ->
    chart = $(this).closest(".linear_chart")
    # Remember selection, if present
    selected_marker = chart.find(".selected_linear_marker")

    # Remove existing chart and reposition container 
    chart.find(".linear_box svg").remove()
    # Have to reposition the scroll so the svg is draw in the right spot
    chart.find(".linear_box").scrollLeft(0)

    if /^Expand Genome/.test($(this).html())
      $(this).html("Condense Genome")

      drawLinear(chart.find(".linear_box")[0], height, long_width, bar_height, abbrevs)

    else
      $(this).html("Expand Genome")

      drawLinear(chart.find(".linear_box")[0], height, width, bar_height, abbrevs)

    # Remember existing options!
    if /^Hide/.test(chart.find('#toggle_labels').html())
      showLabels(this)
    else
      hideLabels(this)

    if /^Show Annotated/.test(chart.find('#toggle_annotated').html())
      showAnnotated(this)
    else
      hideAnnotated(this)

    console.log selected_marker
    if selected_marker.length > 0
      to_select = d3.select("#" + $(selected_marker[0]).attr("id"))
      console.log to_select
      to_select.classed("selected_linear_marker", true)
      linearHighlight(to_select[0])

    return

  # Hide/Show display options
  $(".linear_options #toggle_labels").click () ->
    if /^Hide/.test($(this).html())
      $(this).html("Show Sequence Labels")
      hideLabels(this)
    else
      $(this).html("Hide Sequence Labels")
      showLabels(this)
    return

  # Hide/Show display options
  $(".linear_options #toggle_annotated").click () ->
    if /^Show Annotated/.test($(this).html())
      $(this).html("Show All")
      hideAnnotated(this)
    else
      $(this).html("Show Annotated Only")
      showAnnotated(this)
    return

  # Link to save image
  $(".linear_options #save_image").click () ->
    saveSvgAsPng($(this).closest(".linear_chart").find(".linear_genome")[0], "circular_genome.png", { backgroundColor: '#ffffff' });

  # $(".linear_options  #save_image").click () -> 
  #   region = $(this).closest(".linear_chart").attr("id")
  #   submit_download_form(region + "_svg", "svg", region + "_genome")

drawLinear = (canvas, height, width, bar_height, abbrevs) ->
  # Load up the data
  region_data = $(canvas).data("info")

  # Keep track of sequence locations to help position stuff
  top_count = 0
  bottom_count = 0

  # Define the scale
  x_scale = d3.scale.linear()
              .domain([region_data["start"], region_data["end"]])
              .range([10, width - 10])

  # Then make the axis
  nformat = d3.format(".4s")
  x_axis = d3.svg.axis()
             .scale(x_scale)
             .orient("bottom")
             .ticks(10)
             .tickFormat(nformat)

  # Draw the svg container
  svg = d3.select(canvas).append('svg')
    .attr('width', width)
    .attr('height', height)
    .style('background', '#ffffff')
    .attr('class', 'linear_genome')
    .attr('id', "region_" + region_data["number"] + "_svg")

  # Then add the bars!
  svg.selectAll('rect').data(region_data["sequences"])
    .enter().append('rect')
      .style({'stroke': '#9e9e9e', 'stroke-width': '1px'})
      .attr("class", (data) ->
          return "bar blast_" + data["match"]
      )
      .attr("id", (data, i) ->
        return "linear_bar_" + data["region"] + "_sequence_" + i
      )
      .attr("value", (data, i) ->
          return i
      )
      .attr('width', (data) ->
          return x_scale(data["to"]) - x_scale(data["from"])
      )
      .attr('height', bar_height)
      .attr('x', (data) ->
          return x_scale(data["from"])
      )
      .attr('y', (data) ->
          if parseInt(data["strand"]) > 0
            return (height / 2) - 75
          else
            return (height / 2) + 75 - bar_height
      )

  # Add labels
  svg.selectAll("text")
    .data(region_data["sequences"])
    .enter()
    .append("text")
    .text( (data) ->
      return abbrevs[data["match"]]
    )
    .attr("x", (data) ->
      return x_scale(data["from"]) + ((x_scale(data["to"]) - x_scale(data["from"])) / 2)
    )
    .attr("y", (data, i) ->
        if parseInt(data["strand"]) > 0
          top_count += 1
          if isEven(top_count)
            return (height / 2) - 75 - 35
          else
            return (height / 2) - 75 - 15
        else
          bottom_count += 1
          if isEven(bottom_count)
            (height / 2) + 75 + bar_height + 5
          else
            return (height / 2) + 75 + bar_height - 15
    )
    .attr("class", (data) ->
      return "linear_label"
    )
    .attr("bar", (data, i) ->
      return "linear_bar_" + data["region"] + "_sequence_" + i
    )
    .attr("related_homol", (data) ->
      return "blast_" + data["match"]
    )

  # Reset these
  top_count = 0
  bottom_count = 0

  # Add label lines
  svg.selectAll("line")
    .data(region_data["sequences"])
    .enter()
    .append("line")
    .attr("x1", (data) ->
      return x_scale(data["from"]) + ((x_scale(data["to"]) - x_scale(data["from"])) / 2)
    )
    .attr("x2", (data) ->
      return x_scale(data["from"]) + ((x_scale(data["to"]) - x_scale(data["from"])) / 2)
    )
    .attr("y1", (data, i) ->
        if parseInt(data["strand"]) > 0
          return (height / 2) - 75 - 5
        else
          return (height / 2) + 75 + bar_height - 35
    )
    .attr("y2", (data, i) ->
        if parseInt(data["strand"]) > 0
          top_count += 1
          if isEven(top_count)
            return (height / 2) - 75 - 30
          else
            return (height / 2) - 75 - 10
        else
          bottom_count += 1
          if isEven(bottom_count)
            (height / 2) + 75 + bar_height - 5
          else
            return (height / 2) + 75 + bar_height - 25
    )
    .attr("class", (data) ->
      return "linear_label_line"
    )
    .attr("bar", (data, i) ->
      return "linear_bar_" + data["region"] + "_sequence_" + i
    )
    .attr("related_homol", (data) ->
      return "blast_" + data["match"]
    )

  # Stick the axis in the middle
  svg.append("g").attr("class", "axis")
      .attr("transform", "translate(0," + height / 2 + ")").call(x_axis)

  # Add arrows
  line_start = (width / 2) - 100
  line_end = (width / 2) + 100
  svg.append("line")
    .attr("x1", line_start).attr("x2", line_end)
    .attr("y1", 12).attr("y2", 12)
    .attr("class", "direction_line")
  svg.append("line")
    .attr("x1", line_start).attr("x2", line_start + 5)
    .attr("y1", height - 12).attr("y2", height - 7)
    .attr("class", "direction_line")
  svg.append("line")
    .attr("x1", line_start).attr("x2", line_start + 5)
    .attr("y1", height - 12).attr("y2", height - 17)
    .attr("class", "direction_line")

  svg.append("line")
    .attr("x1", line_start).attr("x2", line_end)
    .attr("y1", height - 12).attr("y2", height - 12)
    .attr("class", "direction_line")
  svg.append("line")
    .attr("x1", line_end).attr("x2", line_end - 5)
    .attr("y1", 12).attr("y2", 7)
    .attr("class", "direction_line")
  svg.append("line")
    .attr("x1", line_end).attr("x2", line_end - 5)
    .attr("y1", 12).attr("y2", 17)
    .attr("class", "direction_line")

  # Show corresponding data when hovering over prophage regions
  $(canvas).find(".bar").mouseenter () ->
    # Hover indicator
    if !d3.select(this).classed("selected_linear_marker")
      linearHighlight(this)

  $(canvas).find(".bar").mouseleave () ->
    if !d3.select(this).classed("selected_linear_marker")
      linearUnhighlight(this)

  # Show data on click
  $(canvas).find(".bar").click () ->
    # Load data from .linear-box
    i = $(this).attr("value")
    sequence_data = $(this).closest(".linear_box").data("info")["sequences"][i]
    chart = $(this).closest(".linear_chart")

    # If this marker is not currently selected
    if !d3.select(this).classed("selected_linear_marker")

      # Remove any other selected
      d3.select(chart[0]).selectAll(".bar.selected_linear_marker")
        .each((data, i) ->
          linearUnhighlight(this)
          d3.select(this).classed("selected_linear_marker", false)
        )

      d3.select(this).classed("selected_linear_marker", true)

      name = sequence_data["protein_name"].split(";")[0]
      location = sequence_data["from"] + "-" + sequence_data["to"] + " (" + (sequence_data["to"] - sequence_data["from"]) + " bps)"
      direction = if parseInt(sequence_data["strand"]) > 0 then "Forward" else "Backward"
      homology = sequence_data["match"].replace("_like", "-like").replace(/_/g, " ").capitalize()
      $(this).closest(".linear_chart").find(".linear_sequence").html("<div class='header blast_" + sequence_data["match"] + "_header'>Locus " + (parseInt(i) + 1).toString() + ": " + name + 
                              " (<a class='modal-trigger' href='#" + sequence_data["region"] + "_linear_" + i + "'>Click for Details " + "<i class='tiny material-icons'>info_outline</i>)</a></div>" +
                              "<b>Location:</b> " + location + "</br>" +
                              "<b>Direction:</b> " + direction + "</br>" +
                              "<b>Homology:</b> " + homology + "</br>" +
                              "<b>Homology E-Value:</b> " + sequence_data["evalue"] + "</br>"
                              )

      $('.modal-trigger').leanModal()
    else
      d3.select(this).classed("selected_linear_marker", false)

      $(this).closest(".linear_chart").find(".linear_sequence").html("Click on a sequence to see details.")

hideLabels = (button) ->
  chart = $(button).closest(".linear_chart")
  selected_marker = chart.find(".selected_linear_marker")
  if selected_marker.length > 0
    chart.find(".linear_label:not([bar='" + $(selected_marker).attr("id") + "'])").css("visibility", "hidden")
    chart.find(".linear_label_line:not([bar='" + $(selected_marker).attr("id") + "'])").css("visibility", "hidden")
  else
    chart.find(".linear_label").css("visibility", "hidden")
    chart.find(".linear_label_line").css("visibility", "hidden")

showLabels = (button) ->
  chart = $(button).closest(".linear_chart")
  if /^Show All/.test(chart.find(".linear_options #toggle_annotated").html())
    chart.find(".linear_label:not([related_homol='blast_hypothetical_protein'])").css("visibility", "visible")
    chart.find(".linear_label_line:not([related_homol='blast_hypothetical_protein'])").css("visibility", "visible")
  else
    chart.find(".linear_label").css("visibility", "visible")
    chart.find(".linear_label_line").css("visibility", "visible")

hideAnnotated = (button) ->
  chart = $(button).closest(".linear_chart")
  chart.find(".blast_hypothetical_protein").css("visibility", "hidden")
  chart.find(".blast_non_phage_like_protein").css("visibility", "hidden")
  chart.find("[related_homol='blast_hypothetical_protein']").css("visibility", "hidden")
  chart.find("[related_homol='blast_non_phage_like_protein']").css("visibility", "hidden")

showAnnotated = (button) ->
  chart = $(button).closest(".linear_chart")
  chart.find(".blast_hypothetical_protein").css("visibility", "visible")
  chart.find(".blast_non_phage_like_protein").css("visibility", "visible")
  if /^Hide/.test(chart.find(".linear_options #toggle_labels").html())
    chart.find("[related_homol='blast_hypothetical_protein']").css("visibility", "visible")
    chart.find("[related_homol='blast_non_phage_like_protein']").css("visibility", "visible")

String.prototype.capitalize = () ->
  return this.charAt(0).toUpperCase() + this.slice(1);

isEven = (n) ->
   return n % 2 == 0

linearHighlight = (element) ->
  i = $(element).attr("value")
  sequence_data = $(element).closest(".linear_box").data("info")["sequences"][i]
  chart = $(element).closest(".linear_chart")

  if /^Show/.test(chart.find(".linear_options #toggle_labels").html())
    chart.find("[bar='" + $(element).attr("id") + "']").css("visibility", "visible")

  # Hover indicator
  $(element).css("stroke", "#303f9f")
  $(element).css("stroke-width", "2px")
  $(".linear_label[bar='" + $(element).attr("id") + "']")
    .css("stroke", "#303f9f")
    .css("fill", "#303f9f")
  $(".linear_label_line[bar='" + $(element).attr("id") + "']")
    .css("stroke", "#303f9f")
    .css("stroke-width", "2px")

linearUnhighlight = (element) ->
  i = $(element).attr("value")
  sequence_data = $(element).closest(".linear_box").data("info")["sequences"][i]
  chart = $(element).closest(".linear_chart")

  if /^Show/.test(chart.find(".linear_options #toggle_labels").html())
    chart.find("[bar='" + $(element).attr("id") + "']").css("visibility", "hidden")

  $(element).css("stroke", "#9e9e9e").css("stroke-width", "1px")
  $(".linear_label[bar='" + $(element).attr("id") + "']")
    .css("stroke", "none")
    .css("fill", "#9e9e9e")
  $(".linear_label_line[bar='" + $(element).attr("id") + "']")
    .css("stroke", "#9e9e9e")
    .css("stroke-width", "1px")
