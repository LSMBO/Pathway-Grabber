function isSheetNameValid(sheetName::String)::Bool
    error = ""
    if(sheetName == "Historique" || sheetName == "History") # must not be "History" or "Historique"
        error = "Excel sheet name '$sheetName' is not valid: names 'History' or 'Historique' are not allowed"
    elseif(length(sheetName) > 32) # must be less than 32 characters
        error = "Excel sheet name '$sheetName' is not valid: name length must be less than 32 characters"
    elseif(first(sheetName, 1) == "'") # must not start or end with an apostrophe
        error = "Excel sheet name '$sheetName' is not valid: name cannot start with an apostrophe"
    elseif(last(sheetName, 1) == "'")
        error = "Excel sheet name '$sheetName' is not valid: name cannot end with an apostrophe"
    elseif(count(c -> iscntrl(c), sheetName) > 0)
        error = "Excel sheet name contain a control character"
    elseif(contains(sheetName, r"[\[\]\:\*\?/\\]")) # must not contains []:*?/\
        error = "Excel sheet name '$sheetName' is not valid: name cannot contain the characters [ ] : * ? \\ /"
    end
    # if(error != "") println(error) end
    if(error != "") @warn error end
    return error == "" # true if valid, then the name seems ok, it just has to be unique but it's not checked here
end

# adds a worksheet with a unique and valid name
# return the created worksheet if it worked
function addWorksheet(workbook::XLSX.XLSXFile, name = nothing)::XLSX.Worksheet
    # easy case: no name given to the sheet
    if name === nothing return XLSX.addsheet!(workbook) end
    # or a name is given but it is not valid
    if !isSheetNameValid(name) return XLSX.addsheet!(workbook) end
    # when a name is provided we have to make sure it's unique
    sheets = XLSX.sheetnames(workbook)
    i = 2
    newSheetName = name
    # avoid infinite loop
    # exit the loop after the first success (hopefully the first try !)
    while count(sheet -> sheet == newSheetName, sheets) > 0 && i < 10
        newSheetName = "$name ($i)"
        i += 1
    end
    # it can happen if there are already 10 sheets with that name, or if the name with the number exceeds 32 characters
    if !isSheetNameValid(name) return XLSX.addsheet!(workbook) end
    # otherwise create the new sheet with the given name
    return XLSX.addsheet!(workbook, newSheetName)
end

function renameWorksheet(workbook::XLSX.XLSXFile, sheetName::String, sheetToRename::Int64)
    newSheetName = sheetName
    if(sheetName !== nothing && sheetName != "" && isSheetNameValid(sheetName) && sheetToRename <= length(XLSX.sheetnames(workbook)))
        sheet = workbook[sheetToRename]
        sheetNames = XLSX.sheetnames(workbook)
        # make sure the name is not already used (only 10 tries to avoid infinite loop)
        i = 2
        while(newSheetName in sheetNames && i < 10)
            newSheetName = "$name ($i)"
            i += 1
        end
        # the new name can still be taken, or become invalid because too long
        if(i < 10 && isSheetNameValid(newSheetName))
            XLSX.rename!(sheet, newSheetName)
        else
            # if so, do not rename at all and return the non-modified sheet name
            newSheetName = sheetnames[sheetToRename]
        end
    end
    return newSheetName
end

# transforms a letter representing an Excel column into its number equivalent
function getColumnId(columnName::String)::Int
    # A -> (65 - 64) * 26^0 -> 1
    # AB -> (65 - 64) * 26^1 + (66 - 64) * 26^0 -> 28
    # ABC -> (65 - 64) * 26^2 + (66 - 64) * 26^1 + (67 - 64) * 26^0 -> 731
    code = 0
    for i in 1:length(columnName)
        code += (Int(uppercase(columnName)[i]) - 64) * 26^(length(columnName) - i)
    end
    return code
end
function getColumnId(columnNames::Vector{String})::Vector{Int}
    return map(name -> getColumnId(name), columnNames)
end

# write an array of values with or without format
# TODO replace calls to writeExcelLineF with this one
function writeExcelLine(sheet::XLSX.Worksheet, row::Int64, cells...)
    if(isa(cells, Tuple{Vector})) cells = cells[1] end
    for col in eachindex(cells)
        # TODO add the format here
        # Formatting cells is not possible yet in Julia
        value = cells[col]
        sheet[row, col] = if(isa(value, Number) && isnan(value)) "NaN" else value end
    end
end

function getOrCreateFile(filename::String, sheetName::String, inputFile::String = "")::Pair{String, String}
    # outputFile = "$filename.xlsx"
    outputFile = endswith(filename, ".xlsx") ? filename : "$filename.xlsx"
    # if there is an input file, make a copy of it
    xlsxMode = if(inputFile != "" && isfile(inputFile))
        Base.Filesystem.cp(inputFile, outputFile, force = true)
        xlsxMode = "rw"
    else "w" end # otherwise create a new file
    sheet = ""
    XLSX.openxlsx(outputFile, mode = xlsxMode) do xf
        # create the new sheet
        sheet = if(xlsxMode == "rw") addWorksheet(xf, sheetName).name
        # or rename the first sheet it if it's a new file
        else renameWorksheet(xf, sheetName, 1) end
    end
    return Pair(outputFile, sheet)
end

function getKeggRelease()::String
    release = ""
    for line in split(REST_GET("$KEGG_URL/info/kegg"), "\n")
        # we want the following line:
        # kegg             Release 106.0+/05-04, May 23
        if(startswith(line, r"kegg +Release "))
            release = replace(line, r".*Release " => "")
        end
    end
    return release
end

function getStatistics(params::Params)::String
    return if(params.statistics == "pvalue") "Anova p-values"
    elseif(params.statistics == "pvalue_fc") "Anova p-values and Fold Change"
    elseif(params.statistics == "conditions") "Anova p-values and multiple conditions each with a Tukey value and a Fold Change"
    else "No statistics" end
end

function getFirstSheet(params::Params, duplicatesRef::Ref{Dict{String, Int64}})::Vector{Vector{Any}}
    lines = Vector{Vector{Any}}()
    push!(lines, ["Tool version", getVersion(string(@__DIR__, "/PathwayGrabber.xml"))])
    push!(lines, ["Search date", getDate("dd U yyyy HH:MM:SS")])
    push!(lines, ["Kegg release", getKeggRelease()])
    push!(lines, ["", "Kegg data is updated after $CACHE_MAX_AGE_IN_DAYS days, some data may belong to the previous version..."])
    push!(lines, ["UniProt release", getUniprotRelease()])
    push!(lines, ["statistical validation", getStatistics(params)])
    push!(lines, ["Anova p-value threshold", params.thresholds.pvalue])
    push!(lines, ["Tukey threshold", params.thresholds.tukey])
    push!(lines, ["Fold change threshold", params.thresholds.fc])
    push!(lines, ["", ""])
    push!(lines, ["Status description", ""])
    for status in collect(values(STATUS))
        push!(lines, [status.text, status.description])
    end
    push!(lines, ["", ""])
    if(!isempty(duplicatesRef[]))
        push!(lines, ["Duplicate entries", "Only the first entry of each duplicate has been considered"])
        for (key, value) in duplicatesRef[]
            push!(lines, [key, "x$value"])
        end
    end
    return lines
end

function getPathways(entry::Entry, genesRef::Ref{Vector{Gene}}, pathwaysRef::Ref{Vector{Pathway}})::Vector{Pathway}
    # gather the pathway ids first
    ids = Vector{String}()
    for gene in filter(g -> entry.id in g.entryIds, genesRef[])
        append!(ids, gene.pathwaysIds)
    end
    # remove duplicate pathways if any
    unique!(ids)
    # return the complete pathways that match these ids
    return filter(p -> p.id in ids, pathwaysRef[])
end

function getPathwayClassLevels(pathway::Pathway)::Tuple{String, String}
    level1 = ""
    level2 = ""
    if(haskey(pathway.data, "CLASS"))
        if(contains(pathway.data["CLASS"][1], ";"))
            level1, level2 = split(pathway.data["CLASS"][1], r" *; *")
        else level1 = pathway.data["CLASS"][1] end
    end
    return (level1, level2)
end

function getPathwaySummary(pathways::Vector{Pathway})::String
    lines = Vector{String}()
    for pw in pathways
        level1, level2 = getPathwayClassLevels(pw)
        if(level1 == "")
            push!(lines, string(pw.id, ":", pw.name))
        elseif(level2 == "")
            push!(lines, string(pw.id, ":", pw.name, ":", level1))
        else
            push!(lines, string(pw.id, ":", pw.name, ":", level1, ":", level2))
        end
    end
    return join(lines, "\n")
end

function getSecondSheet(params::Params, entriesRef::Ref{Vector{Entry}}, genesRef::Ref{Vector{Gene}}, pathwaysRef::Ref{Vector{Pathway}})::Vector{Vector{Any}}
    lines = Vector{Vector{Any}}()
    # add the headers
    headers = Vector{String}()
    if(params.isUniprot) append!(headers, ["User entry", "UniProt identifier"])
    else push!(headers, "Identifier") end
    if(params.hasModificationSites) push!(headers, "Site") end
    if(params.hasConditions) push!(headers, "Condition") end
    push!(headers, "Status")
    push!(headers, "# Maps")
    push!(headers, "Pathway_Map:name:level_1:level_2")
    push!(lines, headers)

    # get the list of entries to display
    entryIds = Vector{String}()
    for gene in genesRef[] append!(entryIds, gene.entryIds) end
    unique!(entryIds)
    entries = filter(e -> e.id in entryIds, entriesRef[])
    # sort to make sure that the conditions and sites are well ordered
    sort!(entries, by = e -> (e.id, e.site, e.condition))
    # remove when all conditions are KO ?
    # Maybe not after all, it's better to keep the same behaviour for all cases

    # add the content
    for entry in entries
        line = Vector{Any}()
        push!(line, entry.id)
        if(params.isUniprot) push!(line, entry.uniprotIdentifier) end
        if(params.hasModificationSites) push!(line, entry.site) end
        if(params.hasConditions) push!(line, entry.condition) end
        push!(line, getStatus(entry.statusId).text)
        pathways = getPathways(entry, genesRef, pathwaysRef)
        push!(line, length(pathways))
        push!(line, getPathwaySummary(pathways))
        push!(lines, line)
    end

    return lines
end

function getCorrespondingEntries(pathway::Pathway, genesRef::Ref{Vector{Gene}})::Vector{String}
    entryIds = Vector{String}()
    for gene in filter(g -> pathway.id in g.pathwaysIds, genesRef[])
        append!(entryIds, gene.entryIds)
    end
    return sort(unique(entryIds))
end

function getThirdSheet(pathwaysRef::Ref{Vector{Pathway}}, genesRef::Ref{Vector{Gene}})::Vector{Vector{Any}}
    lines = Vector{Vector{Any}}()
    # add the headers
    push!(lines, ["Map", "Name", "Level 1", "Level 2", "Nb identifiers", "Identifiers"])
    # add the content
    for pw in pathwaysRef[]
        line = Vector{Any}()
        push!(line, pw.id)
        push!(line, pw.name)
        level1, level2 = getPathwayClassLevels(pw)
        push!(line, level1)
        push!(line, level2)
        entries = getCorrespondingEntries(pw, genesRef)
        push!(line, length(entries))
        push!(line, join(entries, ", "))
        push!(lines, line)
    end
    return lines
end

function generateTsvFile(fileName::String, data::Vector{Vector{Any}})
    out = open(fileName, "w")
    for line in data
        write(out, "$(join(line, "\t"))&crlf;") # using &crlf; instead of \n because there does not seem to be any easy way to read csv files
    end
    # CSV.write(fileName, Tables.table(data), writeheader = false)
end

function writeExcelOutput(params::Params, entriesRef::Ref{Vector{Entry}}, genesRef::Ref{Vector{Gene}}, pathwaysRef::Ref{Vector{Pathway}}, duplicatesRef::Ref{Dict{String, Int64}}, tempDirectory::String, alsoGenerateTsvFiles::Bool = false)::String
    xlsxFile = string("$tempDirectory/PathwayGrabber.xlsx")
    @info "Creating the output file '$xlsxFile'"
    xlsxFile, sheetName = getOrCreateFile(xlsxFile, "PathwayGrabber settings", params.input.path)
    XLSX.openxlsx(xlsxFile, mode = "rw") do xf
        # add a summary sheet
        sheet1 = xf[sheetName]
        content = getFirstSheet(params, duplicatesRef)
        for i in eachindex(content) writeExcelLine(sheet1, i, content[i]) end
        if(alsoGenerateTsvFiles) generateTsvFile("$tempDirectory/Summary.tsv", content) end
        # if(alsoGenerateTsvFiles) writedlm("$tempDirectory/Summary.tsv", replace(content, r"\n" => "&crlf;"), "\t") end
        # then the output by entry
        sheet2 = addWorksheet(xf, "Results by entry")
        content = getSecondSheet(params, entriesRef, genesRef, pathwaysRef)
        for i in eachindex(content) writeExcelLine(sheet2, i, content[i]) end
        if(alsoGenerateTsvFiles) generateTsvFile("$tempDirectory/Entries.tsv", content) end
        # if(alsoGenerateTsvFiles) writedlm("$tempDirectory/Entries.tsv", replace(content, r"\n" => "&crlf;"), "\t") end
        # and the output by pathway
        sheet3 = addWorksheet(xf, "Results by pathway")
        content = getThirdSheet(pathwaysRef, genesRef)
        for i in eachindex(content) writeExcelLine(sheet3, i, content[i]) end
        if(alsoGenerateTsvFiles) generateTsvFile("$tempDirectory/Maps.tsv", content) end
        # if(alsoGenerateTsvFiles) writedlm("$tempDirectory/Maps.tsv", replace(content, r"\n" => "&crlf;"), "\t") end
    end
    return xlsxFile
end
