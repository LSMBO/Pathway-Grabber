TRANSLATE = 6

function getCombinations()::Vector{String}
    combs = Vector{String}()
    codes = map(st -> st.code, collect(values(STATUS)))
    for set in powerset(codes)
        if(!isempty(set)) push!(combs, join(sort(set), "-")) end
        # if(!isempty(set)) push!(combs, join(sort(unique(set)), "-")) end
    end
    return combs
end

function makeCss(tabs::String)::Vector{String}
    lines = Vector{String}()
    push!(lines, "$(tabs)html { font-family:Calibri; }")
    push!(lines, "$(tabs)a { z-index: 50; }")
    push!(lines, "$(tabs)a.h.rect, a.h.circ { border-color:#f2549e; }")
    push!(lines, "$(tabs)a.h.arrow, a.h.line { background-color:#f2549e; }")
    push!(lines, "$(tabs)a.rect, a.arrow, a.circ, a.line { border: 3px solid transparent; position: absolute; z-index: 10; }")
    push!(lines, "$(tabs)a.rect.rounded { border-radius: 10px; }")
    push!(lines, "$(tabs)a.circ { border-radius: 50%; mask-image: radial-gradient(circle, transparent 40%, rgba(0, 0, 0, 1) 0); }")
    push!(lines, "$(tabs)div.TT { visibility:hidden; width:max-content; max-width:500px; background-color:#f9f9f9; border:1px solid gray; color:black; position:absolute; left: 0; top: 0; z-index: 20; }")
    push!(lines, "$(tabs)div#help { position:absolute; top:8px; left:8px; border:1px solid black; padding:1px 5px }")
    push!(lines, "$(tabs)div#legend { visibility:hidden; width:max-content; background-color:#555; color:white; padding:5px 10px; position:fixed; left: 8px; top: 8px; z-index: 20; }")
    push!(lines, "$(tabs)div#legend p { line-height: 10px; }")
    push!(lines, "$(tabs)div#legend font { font-weight: bold; }")
    push!(lines, "$(tabs)table#info { visibility:hidden; width:75%; background-color:#555; color:white; padding:5px 10px; position:fixed; left: 8px; top: 8px; z-index: 20; }")
    push!(lines, "$(tabs)table#info td { min-width: 150px; vertical-align : top; }")
    push!(lines, "$(tabs)table#info td a { color: #ffd561; }")
    push!(lines, "$(tabs)table#info td a:hover { color: #fcba03; }")
    push!(lines, "$(tabs)table#info td a:visited { color: #fcba03; }")
    push!(lines, "$(tabs)table#info td a:visited:hover { color: #9e843e; }")
    ps = join(map(st -> "p.$(st.code)", collect(values(STATUS))), ", ")
    push!(lines, "$(tabs)$ps, p.NA, p.title { line-height: 25px; padding: 0px 5px 0px 0px; margin: 0; border-bottom: 1px solid #ccc; }")
    psb = join(map(st -> "p.$(st.code)::before", collect(values(STATUS))), ", ")
    push!(lines, "$(tabs)$psb, p.NA::before { display:inline-block; width:25px; margin-right:5px; text-align:center; }")
    push!(lines, "$(tabs)p.title { color: white; background-color: #555; padding-left: 10px; }")
    for status in collect(values(STATUS))
        push!(lines, "$(tabs)p.$(status.code)::before { content:\"$(status.symbol)\"; background-color:$(status.color); }")
        push!(lines, "$(tabs)p.$(status.code)::after { content:\": $(status.text)\"; }")
    end
    push!(lines, "$(tabs)p.NA::before { content:\"\\2022\"; background-color:white; color: #555; }")
    for combination in getCombinations()
        colors = map(st -> getStatus(string(st)).color, split(combination, "-"))
        # if only one color (ie. DO or OK), double the color to make a gradient from A to A
        if(length(colors) == 1) push!(colors, colors[1]) end
        # add the rules
        tcolors = join(colors, ", ")
        push!(lines, "$(tabs)a.$combination { border-image: linear-gradient(to right, $tcolors) 1; }")
        push!(lines, "$(tabs)a.arrow.$combination, a.line.$combination { background-image: linear-gradient(to right, $tcolors); }")
    end
    push!(lines, "$(tabs)a.blink { animation: 1s linear infinite jiggler; }")
    push!(lines, "$(tabs)@keyframes jiggler { from { transform: rotate(0deg) translateX(10px) rotate(0deg); } to { transform: rotate(360deg) translateX(10px) rotate(-360deg); }}")
    return lines
end

function getImage(file::String)::String
    h, w = size(load(file))
    base64 = base64encode(read(file))
    return string("<img width=\"$(w)px\" height=\"$(h)px\" src=\"data:image/png;base64,", base64, "\" />")
end

function getLegend(params::Params, tabs::String)::Vector{String}
    lines = Vector{String}()
    bull1 = "&bull;&nbsp;"
    bull2 = "&nbsp;&nbsp;&nbsp;&bull;&nbsp;"
    push!(lines, "$tabs<div id=\"legend\">")
    push!(lines, "$tabs\t<p>$bull1 The elements can have one or more of the following shape:</p>")
    push!(lines, "$tabs\t<p>$bull2 Rectangles represent a gene product and its complex (including an ortholog group)</p>")
    push!(lines, "$tabs\t<p>$bull2 Round rectangles represent a linked pathway</p>")
    push!(lines, "$tabs\t<p>$bull2 Lines represent a reaction or a relation (and also a gene or an ortholog group)</p>")
    push!(lines, "$tabs\t<p>$bull2 Circles specify any other molecule such as a chemical compound and a glycan</p>")
    if(params.indicateStatus)
        push!(lines, "$tabs\t<p>$bull1 An element can have one or more of the following status:</p>")
        for (key, status) in STATUS
            if(!params.hasConditions || key != KO) # do not display this status in this case
                push!(lines, string("$tabs\t<p>$bull2 Symbol <font style=\"color:", status.color, "\">", status.html, "</font> means \"", status.text, "\": ", status.description, "</p>"))
            end
        end
    end
    push!(lines, "$tabs\t<p>$bull1 Shortcuts:</p>")
    push!(lines, "$tabs\t<p>$bull2 Press 'E' to display information on the current Entry</p>")
    push!(lines, "$tabs\t<p>$bull2 Press 'J' to make the elements Jiggle</p>")
    push!(lines, "$tabs\t<p>$bull2 Press 'H' to Highlight the other links</p>")
    push!(lines, "$tabs</div>")
    return lines
end

function format(tag::String, value::String)::String
    # some tags have to be transformed to URLs
    return if(tag in ["ENTRY", "REL_PATHWAY", "KO_PATHWAY", "PATHWAY_MAP"])
        id = split(value, " ")[1] # value may have text after a space character
        type = (tag == "ENTRY" || tag == "KO_PATHWAY" ? "entry" : "pathway")
        "<a href='https://www.kegg.jp/$type/$id' target='_blank'>$value</a>"
    else value end
end

function getInfo(pathway::Pathway, tabs::String)::Vector{String}
    lines = Vector{String}()
    push!(lines, "$tabs<table id=\"info\">")
    for tag in collect(keys(pathway.data))
        key = tag
        for value in pathway.data[tag]
            push!(lines, string("$tabs\t<tr><td>", titlecase(key), "</td><td>", format(tag, value), "</td></tr>"))
            key = "" # if there are multiple lines to show, only display the title once
        end
    end
    push!(lines, "$tabs</table>")
    return lines
end

function getHtmlStartOfFile(params::Params, pathway::Pathway, pngFile::String)::Vector{String}
    lines = Vector{String}()
    append!(lines, ["<!DOCTYPE html>", "<html>", "\t<head>", "\t\t<title>$(pathway.name)</title>", "\t\t<style>"])
    append!(lines, makeCss("\t\t\t"))
    append!(lines, ["\t\t</style>", "\t</head>", "\t<body>"])
    img = getImage(pngFile)
    append!(lines, ["\t\t$img", "\t\t<div id='help'>Press L to display the legend</div>"])
    append!(lines, getLegend(params, "\t\t")) # do not show status if statistics == none
    append!(lines, getInfo(pathway, "\t\t"))
    return lines
end

function isCircle(type::String)::Bool
    return startswith(type, "circ ") || startswith(type, "filled_circ ")
end

function isLine(type::String)::Bool
    return startswith(type, "line ")
end

function isPolygon(type::String)::Bool
    return startswith(type, "poly ")
end

function isRectangle(type::String)::Bool
    return startswith(type, "rect ")
end

function getPoints(text::String, addTranslation::Bool = false)::Vector{Point}
    # text must be like: (541,878) or (941,1266,...,898,1266)
    points = Vector{Point}()
    # transform the text into a list of numbers
    values = map(v -> parse(Int64, v), split(replace(text, r"[()]" => ""), ","))
    # translate on demand
    if(addTranslation) values = values .+ TRANSLATE end
    # the points should be odd (multiple of 2)
    if(length(values) % 2 == 0)
        # make pairs
        for i in 1:2:length(values)
            push!(points, Point(values[i], values[i + 1]))
        end
    end
    return points
end

function getCircleStyle(type::String)::String
    # type looks like: circ (541,878) 4
    point = getPoints(string(split(type, " ")[2]))[1]
    radius = parse(Int64, split(type, " ")[3])
    left = round(point.x - radius / 2 + TRANSLATE, digits = 2)
    top = round(point.y - radius / 2 + TRANSLATE, digits = 2)
    return "left:$(left)px;top:$(top)px;width:$(radius)px;height:$(radius)px;"
end

function getRectangleStyle(type::String)::String
    # type looks like: rect (468,880) (514,897)
    point1 = getPoints(string(split(type, " ")[2]))[1]
    point2 = getPoints(string(split(type, " ")[3]))[1]
    left = point1.x + TRANSLATE
    top = point1.y + TRANSLATE
    width = abs(point2.x - point1.x)
    height = abs(point2.y - point1.y)
    return "left:$(left)px;top:$(top)px;width:$(width)px;height:$(height)px"
end

function getTopLeftWidthHeight(points::Vector{Point})::Vector{Int64}
    minX = minimum(map(p -> p.x, points))
    minY = minimum(map(p -> p.y, points))
    maxX = maximum(map(p -> p.x, points))
    maxY = maximum(map(p -> p.y, points))
    return [minY, minX, maxX - minX, maxY - minY]
end

function getLineStyle(type::String)::String
    # type looks like: line (941,1266,898,1266) 3
    # values in parentheses are a list of [x,y] coordinates
    # last value is the width of the line but usually negligeable
    items = split(type, " ")
    points = getPoints(string(items[2]), true)
    # get values top, left, width and height
    top, left, width, height = getTopLeftWidthHeight(points)
    # add coordinates twice, with a small modification to avoid an invisible 1D shape
    strength = parse(Int64, items[3]) + 2
    forward = Vector{String}()
    backward = Vector{String}()
    for p in points
        push!(forward, string(p.x - left + strength - 1, ",", p.y - top + strength - 1))
        push!(backward, string(p.x - left + strength + 1, ",", p.y - top + strength + 1))
    end
    append!(forward, reverse(backward))
    return string("top:$(top)px;left:$(left)px;width:$(width)px;height:$(height)px;clip-path:path('M ", join(forward, " L "), " Z');")
end

function getDistance(a::Point, b::Point)::Float64
    return sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

function getTotalDistance(point::Point, a::Point, b::Point, c::Point)::Float64
    return getDistance(point, a) + getDistance(point, b) + getDistance(point, c)
end

function arrowToTriangle(points::Vector{Point})::Vector{Point}
    # when there are 4 points, it's a arrow head
    if(length(points) == 4)
        # in this case we want to remove the central point to transform the arrow head to a triangle
        distances = Dict{Int64, Float64}()
        distances[1] = getTotalDistance(points[1], points[2], points[3], points[4])
        distances[2] = getTotalDistance(points[2], points[1], points[3], points[4])
        distances[3] = getTotalDistance(points[3], points[1], points[2], points[4])
        distances[4] = getTotalDistance(points[4], points[1], points[2], points[3])
        # remove the point that has the lowest distance
        popat!(points, findmin(distances)[2])
    end
    return points
end

function getPointsAtADistance(a::Float64, b::Float64, p::Point, dist::Float64)::Vector{Point}
    # let's assume a line with the equation a*x + b and a point p on this line
    # get the delta formula: Delta = b² - 4ac
    deltaA = a ^ 2 + 1
    deltaB = -2 * p.x + 2 * a * b - 2 * a * p.y
    deltaC = p.x ^ 2 + p.y ^ 2 - dist ^ 2 + b ^ 2 - 2 * b * p.y
    delta = deltaB ^ 2 - 4 * deltaA * deltaC
    # delta has to be positive to get the two points we want
    return if(delta > 0) # this should always happen
        # we want the points that are at a distance dist of the point p along this line
        x1 = round((-1 * deltaB - sqrt(delta)) / (2 * deltaA), digits = 2)
        x2 = round((-1 * deltaB + sqrt(delta)) / (2 * deltaA), digits = 2)
        [Point(x1, round(a * x1 + b, digits = 2)), Point(x2, round(a * x2 + b, digits = 2))]
    elseif(delta == 0) # there is only one solution
        x = round((-1 * deltaB) / (2 * deltaA), digits = 2)
        [Point(x, a * x + b)]
    else [] end
end

function getSide(point::Point, lineA::Point, lineB::Point)::Float64
    # if point is on the right of the line AB, return a positive value
    # if point is on the left of the line AB, return a negative value
    # if point is on the line AB, return zero
    return ((lineA.x - lineB.x) * (point.y - lineA.y) - (lineA.y - lineB.y) * (point.x - lineA.x))
end

# this function will return a point that is slightly further
# when applied to all the summits of the arrow, it should make a slightly bigger arrow (so it's easier to see it on a big image, and easier to click on it)
function transformArrowSummit(a::Point, b::Point, c::Point)::Point
    # get the coordinates of the point BC between B and C
    bc = Point(round((b.x + c.x) / 2, digits = 2), round((b.y + c.y) / 2, digits = 2))
    # calculate the equation of the line A_BC : y = a_bc_a * x + a_bc_b
    a_bc_a::Float64 = (a.x != bc.x ? (bc.y - a.y) / (bc.x - a.x) : 0)
    a_bc_b::Float64 = a.y - a_bc_a * a.x
    # get the distance between A and BC
    d = round(getDistance(a, bc), digits = 2)
    # find the coordinates of the 2 points on the line A_BC with a distance of d+1 from point BC
    points = getPointsAtADistance(a_bc_a, a_bc_b, bc, d + 2) # we add 2 to the distance
    return if(length(points) == 2)
        # get on which side is A compared to the line BC
        sideA = getSide(a, b, c)
        # get on which side is p1 compared to the line BC
        side1 = getSide(points[1], b, c)
        # return the point that is on the same side of line BC
        (sideA > 0 && side1 > 0) || (sideA < 0 && side1 < 0) ? points[1] : points[2]
    else a end # this should never happen, but if it does return the original point
end

function transformPolygonCoordinates(points::Vector{Point})::Vector{Point}
    # at this step, points should always have 3 elements
    newPoints = Vector{Point}()
    if(length(points) == 3)
        push!(newPoints, transformArrowSummit(points[1], points[2], points[3]))
        push!(newPoints, transformArrowSummit(points[2], points[1], points[3]))
        push!(newPoints, transformArrowSummit(points[3], points[1], points[2]))
    end
    return newPoints
end

function getPolygonStyle(type::String)::String
    # type looks like: poly (967,617,963,608,970,608)
    # polygons are representing triangles at the end of a arrow line
    points = arrowToTriangle(getPoints(string(split(type, " ")[2]), true))
    # get values top, left, width and height
    top, left, width, height = getTopLeftWidthHeight(points)
    newPoints = transformPolygonCoordinates(points)
    coords = Vector{String}()
    for p in newPoints
        push!(coords, string(round(p.x - left + 3, digits = 2), "px ", round(p.y - top + 3, digits = 2), "px"))
    end
    return string("top:$(top)px;left:$(left)px;width:$(width)px;height:$(height)px;clip-path:polygon(", join(coords, ", "), ");")
end

function getStyle(type::String)::String
    return if(isCircle(type)) getCircleStyle(type)
    elseif(isRectangle(type)) getRectangleStyle(type)
    elseif(isLine(type)) getLineStyle(type)
    elseif(isPolygon(type)) getPolygonStyle(type)
    else "" end # should not happen
end

function getClass(type::String, url::String)::String
    return if(isCircle(type)) "circ"
    elseif(isRectangle(type)) contains(url, "show_pathway") ? "rect rounded" : "rect"
    elseif(isLine(type)) "line"
    elseif(isPolygon(type)) "arrow"
    else "" end # should not happen
end

function getGenes(url::String, genesRef::Ref{Vector{Gene}})::Vector{Gene}
    # url is like: # /dbget-bin/www_bget?hsa:2203+hsa:8789
    # we want ["hsa:2203", "hsa:8789"] but it can also contain pathway ids
    genes = Vector{Gene}()
    for id in split(split(url, "?")[2], "+")
        append!(genes, filter(gene -> gene.id == id || id in gene.pathwaysIds, genesRef[]))
    end
    return sort(genes, by = gene -> gene.id)
end

function makeTooltipText(params::Params, id::String, name::String, entriesRef::Ref{Vector{Entry}}, genesRef::Ref{Vector{Gene}}, tabs::String)::Vector{String}
    lines = Vector{String}()
    push!(lines, "$tabs<div id=\"$(id)tt\" class=\"TT\">")
    push!(lines, "$tabs\t<p class=\"title\">$name</p>")
    for gene in genesRef[]
        for entry in filter(e -> e.id in gene.entryIds, entriesRef[])
            if(!params.hasConditions || entry.statusId != KO) # do not display this status in this case
                status = getStatus(params.indicateStatus ? entry.statusId : 0)
                text = params.hasModificationSites ? "$(entry.id) at site $(entry.site)" : entry.id
                if(params.hasConditions) text *= " [$(entry.condition)]" end
                push!(lines, "$tabs\t<p class=\"$(status.code)\">$text</p>")
            end
        end
    end
    push!(lines, "$tabs</div>")
    return length(lines) == 3 ? Vector{String}() : lines
end

function getFullStatus(params::Params, entriesRef::Ref{Vector{Entry}}, genesRef::Ref{Vector{Gene}})::String
    fullStatus = "Default"
    statuses = Vector{String}()
    if(!isempty(genesRef[]))
        for gene in genesRef[]
            for entry in filter(e -> e.id in gene.entryIds, entriesRef[])
                if(!params.hasConditions || entry.statusId != KO) # do not display this status in this case
                    push!(statuses, getStatus(entry.statusId).code)
                end
            end
        end
        # fullStatus = join(sort(statuses), "-")
        fullStatus = join(sort(unique(statuses)), "-")
    end
    return fullStatus
end

function getHtmlBody(params::Params, confFile::String, entriesRef::Ref{Vector{Entry}}, genesRef::Ref{Vector{Gene}})::Vector{String}
    lines = Vector{String}()
    id = 0
    open(confFile, "r") do reader
        while !eof(reader)
            items = split(readline(reader), "\t")
            if(length(items) == 3)
                id += 1
                type, url, name = map(i -> string(i), items)
                style = getStyle(type)
                class = getClass(type, url)
                genes = getGenes(url, genesRef)
                tooltipLines = makeTooltipText(params, "A$(id)", name, entriesRef, Ref(genes), "\t\t")
                title = "title=\"$name\""
                if(!isempty(tooltipLines))
                    class = string(class, " WITHTT ", getFullStatus(params, entriesRef, Ref(genes)))
                    title = "" # it's in the tooltip
                end
                push!(lines, "\t\t<a id=\"A$id\" class=\"$class\" style=\"$style\" $title href=\"$KEGG_WWW$url\" target=\"_blank\"></a>")
                append!(lines, tooltipLines)
            end
        end
    end
    return lines
end

function makeJs(tabs::String)::Vector{String}
    # if one day we want to display elements without having to keep a key pressed:
    # then comment the keyup listener, and use the following methods
    # function toggle(e) { e.style.visibility=e.style.visibility=='visible'?'hidden':'visible'; }
    # function toggleClass(e,c) { e.classList.toggle(c); }
    lines = Vector{String}()
    push!(lines, "$(tabs)function moveTooltip(e){var tt = document.getElementById(this.id + 'tt');var n = 15;var lmin = e.pageX + n;var tmin = e.pageY + n*2;var ttleft = Math.min(lmin, window.innerWidth + window.pageXOffset - tt.offsetWidth - n*2);var tttop = Math.min(tmin, window.innerHeight + window.pageYOffset - tt.offsetHeight - n*2);if(ttleft != lmin + n && tttop != tmin) tttop = e.pageY - tt.offsetHeight - n*2;tt.style.left = ttleft + 'px';tt.style.top = tttop + 'px';};")
    push!(lines, "$(tabs)function showTooltip(e){ document.getElementById(this.id + 'tt').style.visibility = 'visible'; };")
    push!(lines, "$(tabs)function hideTooltip(e){ document.getElementById(this.id + 'tt').style.visibility = 'hidden'; };")
    push!(lines, "$(tabs)var items = document.getElementsByClassName('WITHTT');")
    push!(lines, "$(tabs)var anchors = document.getElementsByTagName('a');")
    push!(lines, "$(tabs)for(var i = 0; i < items.length; i++) {")
    push!(lines, "$(tabs)\titems[i].addEventListener('mousemove', moveTooltip);")
    push!(lines, "$(tabs)\titems[i].addEventListener('mouseenter', showTooltip);")
    push!(lines, "$(tabs)\titems[i].addEventListener('mouseleave', hideTooltip);")
    push!(lines, "$(tabs)};")
    push!(lines, "$(tabs)document.addEventListener('keydown', event => {")
    push!(lines, "$(tabs)\tif(event.keyCode == 72) {")
    push!(lines, "$(tabs)\t\tfor(var i = 0; i < anchors.length; i++) { anchors[i].classList.add('h'); }")
    push!(lines, "$(tabs)\t} else if(event.keyCode == 69) {")
    push!(lines, "$(tabs)\t\tdocument.getElementById('info').style.visibility = 'visible';")
    push!(lines, "$(tabs)\t} else if(event.keyCode == 76) {")
    push!(lines, "$(tabs)\t\tdocument.getElementById('legend').style.visibility = 'visible';")
    push!(lines, "$(tabs)\t} else if(event.keyCode == 74) {")
    push!(lines, "$(tabs)\t\tfor(var i = 0; i < items.length; i++) { items[i].classList.add('blink'); }")
    push!(lines, "$(tabs)\t}")
    push!(lines, "$(tabs)});")
    push!(lines, "$(tabs)document.addEventListener('keyup', event => {")
    push!(lines, "$(tabs)\tif(event.keyCode == 72) for(var i = 0; i < anchors.length; i++) { anchors[i].classList.remove('h'); };")
    push!(lines, "$(tabs)\tif(event.keyCode == 74) for(var i = 0; i < items.length; i++) { items[i].classList.remove('blink'); };")
    push!(lines, "$(tabs)\tif(event.keyCode == 69) document.getElementById('info').style.visibility = 'hidden';")
    push!(lines, "$(tabs)\tif(event.keyCode == 76) document.getElementById('legend').style.visibility = 'hidden';")
    push!(lines, "$(tabs)});")
    return lines
end

function getHtmlEndOfFile()::Vector{String}
    lines = Vector{String}()
    push!(lines, "\t\t<script type=\"text/javascript\">")
    append!(lines, makeJs("\t\t\t"))
    push!(lines, "\t\t</script>")
    push!(lines, "\t</body>")
    push!(lines, "</html>")
    return lines
end

function getHtmlContent(params::Params, pathway::Pathway, confFile::String, pngFile::String, entriesRef::Ref{Vector{Entry}}, genesRef::Ref{Vector{Gene}})::Vector{String}
    lines = Vector{String}()
    # create the HTML file and header
    append!(lines, getHtmlStartOfFile(params, pathway, pngFile))
    # create links for the SVG elements based on the coordinates of confFile
    append!(lines, getHtmlBody(params, confFile, entriesRef, genesRef))
    # JS has to be written at the end, so the HTML elements already exist
    append!(lines, getHtmlEndOfFile())
    return lines
end

function createHtmlFile(params::Params, pathway::Pathway, confFile::String, pngFile::String, entriesRef::Ref{Vector{Entry}}, genesRef::Ref{Vector{Gene}}, tempDirectory::String = TEMP_DIRECTORY)::String
    htmlFile = getHtmlFile(tempDirectory, pathway.id)
    out = open(htmlFile, "w")
    for line in getHtmlContent(params, pathway, confFile, pngFile, entriesRef, genesRef)
        write(out, "$line\n")
    end
    close(out)
    return htmlFile
end