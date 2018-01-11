$ ->
  $window = $(window)
  width = $window.width() - 430
  if $('#contigs-box').length
    drawContigs('#contigs-box', width)

  $window.resize () ->
    if $('#contigs-box').length
      width = $window.width() - 430
      selected_marker_id = $('.marker.selected_marker').attr('id')
      $('#contigs-box').html('')
      drawContigs('#contigs-box', width)
      if selected_marker_id
        $('#' + selected_marker_id).click()

      if /^Hide/.test($("#plasmid-legend #toggle_lines").html())
        $(this).html("Hide Label Lines")
        $(".region_line").css("visibility", "visible")
      else
        $(this).html("Show Label Lines")
        $(".region_line").css("visibility", "hidden")

drawContigs = (canvas, width) ->
  contig_top_margin = 60
  contig_side_margin = 20
  contig_height = 20
  contig_spacing = 115 # Height of each contig section. Include contig height.
  label_line_length = 32
  marker_line_length = 8

  contigs = $(canvas).data("info")
  console.log(contigs)

  height = contigs.length * contig_spacing + contig_top_margin

  max_length = d3.max(contigs, (contig) -> contig.length)

  # Define the scale
  x_scale = d3.scale.linear()
              .domain([0, max_length])
              .range([contig_side_margin, width - contig_side_margin])


  # Draw the svg container
  svg = d3.select(canvas).append('svg')
    .attr('width', width + contig_side_margin)
    .attr('height', height)
    .style('background', '#ffffff')
    .attr('id', 'contig_genome')

  # Draw the Contigs
  svg.selectAll('rect.contigs').data(contigs)
    .enter().append('rect')
      .attr("class", "contigs")
      .style({'stroke': '#bdbdbd', 'stroke-width': '1px', 'fill': '#e0e0e0'})
      .attr('width', (data) ->
          return x_scale(data["length"])
      )
      .attr('height', contig_height)
      .attr('x', (data) ->
          return x_scale(0)
      )
      .attr('y', (data, i) ->
        return (i * contig_spacing) + contig_top_margin
      )


  # Add axis to bottom of every contig
  nformat = d3.format(".3s")
  for contig, i in contigs
    y = (i * contig_spacing) + contig_height + contig_top_margin
    contig_x_scale = d3.scale.linear()
                .domain([0, contig.length])
                .range([contig_side_margin, x_scale(contig.length) + contig_side_margin])
    tick_num = d3.round(contig.length / max_length * 10)
    x_axis = d3.svg.axis()
               .scale(contig_x_scale)
               .orient("bottom")
               .ticks(tick_num)
               .tickFormat(nformat)
    svg.append("g").attr("class", "axis")
        .attr("transform", "translate(0," + y + ")").call(x_axis)


  # Draw the Contigs Names
  svg.selectAll('text.contig_name').data(contigs)
    .enter().append('text')
      .attr("class", "contig_name")
      .attr("dominant-baseline", "text-before-edge")
      .text( (data) ->
        return data.name
      )
      .attr('x', (data) ->
          return x_scale(0)
      )
      .attr('y', (data, i) ->
        return (i * contig_spacing) + contig_top_margin + contig_height + 20
      )

  for contig, contig_index in contigs
    contig_id = 'contig_index_' + contig_index
    # Create group for each region
    region_groups = svg.selectAll('rect.' + contig_id).data(contig.regions).enter().append('g')
      .attr("region", (data) -> 
        return "region_" + data["number"]
      )
    # Draw Regions
    region_groups.append('rect')
      .attr("id", (data) ->
        return "region_" + data["number"]
      )
      .attr("class", (data) ->
        return "marker " + data["completeness"] + " " + contig_id
      )
      .attr('width', (data) ->
        return x_scale(data["end"]) - x_scale(data["start"])
      )
      .attr('height', contig_height)
      .attr('x', (data) ->
          return x_scale(data.start)
      )
      .attr('y', (data) ->
        return (contig_index * contig_spacing) + contig_top_margin
      )

    # Draw Label Lines
    region_groups.append('line')
      .attr("class", (data) ->
        return "region_line " + data["completeness"] + "_line"
      )
      .attr('x1', (data) ->
        return x_scale(data["start"]) + ((x_scale(data["end"]) - x_scale(data["start"])) / 2)
      )
      .attr('y1', (data) ->
        return (contig_index * contig_spacing) + contig_top_margin
      )
      .attr('x2', (data) ->
        return x_scale(data["start"]) + ((x_scale(data["end"]) - x_scale(data["start"])) / 2)
      )
      .attr('y2', (data) ->
        return (contig_index * contig_spacing) + contig_top_margin - label_line_length
      )

    region_groups.append('text')
      .attr("class", (data) ->
        return "mlabel " + data["completeness"]
      )
      .style({'text-anchor': 'middle'})
      .text( (data) ->
        return data["number"]
      )
      .attr('x', (data) ->
        return x_scale(data["start"]) + ((x_scale(data["end"]) - x_scale(data["start"])) / 2)
      )
      .attr('y', (data, i) ->
        return (contig_index * contig_spacing) + contig_top_margin - label_line_length - 5
      )

    # Draw Start Lines
    region_groups.append('line')
      .attr("class", (data) ->
        return "border_line " + data["completeness"] + "_line"
      )
      .attr('x1', (data) ->
        return x_scale(data["start"])
      )
      .attr('y1', (data) ->
        return (contig_index * contig_spacing) + contig_top_margin
      )
      .attr('x2', (data) ->
        return x_scale(data["start"]) - 2
      )
      .attr('y2', (data) ->
        return (contig_index * contig_spacing) + contig_top_margin - marker_line_length
      )
    # Draw Start Labels
    region_groups.append('text')
      .attr("class", (data) ->
        return "blabel " + data["completeness"]
      )
      .style({'text-anchor': 'middle'; 'font-size': '8px'})
      .attr("dominant-baseline", "central")
      .text( (data) ->
        return nformat(data["start"])
      )
      .style('text-anchor', 'start')
      .attr("transform", (data) ->
        x =  x_scale(data["start"]) - 2
        y =  (contig_index * contig_spacing) + contig_top_margin - marker_line_length
        return "translate(" + x + "," + y + ")rotate(-90)"
      )
    # Draw End Lines
    region_groups.append('line')
      .attr("class", (data) ->
        return "border_line " + data["completeness"] + "_line"
      )
      .attr('x1', (data) ->
        return x_scale(data["end"])
      )
      .attr('y1', (data) ->
        return (contig_index * contig_spacing) + contig_top_margin
      )
      .attr('x2', (data) ->
        return x_scale(data["end"]) + 2
      )
      .attr('y2', (data) ->
        return (contig_index * contig_spacing) + contig_top_margin - marker_line_length
      )
    # Draw End Labels
    region_groups.append('text')
      .attr("class", (data) ->
        return "blabel " + data["completeness"]
      )
      .style({'text-anchor': 'middle'; 'font-size': '8px'})
      .attr("dominant-baseline", "central")
      .text( (data) ->
        return nformat(data["end"])
      )
      .style('text-anchor', 'start')
      .attr("transform", (data) ->
        x =  x_scale(data["end"]) + 2
        y =  (contig_index * contig_spacing) + contig_top_margin - marker_line_length
        return "translate(" + x + "," + y + ")rotate(-90)"
      )

