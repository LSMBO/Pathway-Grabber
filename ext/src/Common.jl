function getDate(format::String = "YYYY-mm-dd HH:MM:SS")::String
    # "yyyymmdd" => 20200127
    # "mm/dd/yyyy" => 01/27/2020
    # "dd U yyyy HH:MM:SS" => 07 January 2022 08:08:06
    # "d u yy H:M:S" => 7 Jan 22 8:8:6
    # no timezone in julia formating (there is a package for that)
    return Dates.format(now(), format)
end

# this function reads the xml file and returns its version number
function getVersion(xmlFile::String)::String
    # find the version in the xml file
    name = ""
    version = ""
    open(xmlFile, "r") do reader
        while !eof(reader)
            line = readline(reader)
            n = match(r"<tool ", line)
            if n !== nothing 
                rName = match(r"name\s*=\s*\"([^\"]+)\"", line)
                if rName !== nothing name = rName.captures[1] end
                rVersion = match(r"version\s*=\s*\"([^\"]+)\"", line)
                if rVersion !== nothing version = rVersion.captures[1] end
            end
        end
    end
    return if name == "" version else "$name $version" end
end

# this function reads the xml file and returns its version number
function getDescription(xmlFile::String)::String
    # find the version in the xml file
    description = ""
    open(xmlFile, "r") do reader
        record = false
        while !eof(reader)
            line = readline(reader)
            if(contains(line, "<help>")) record = true end
            if(record) description *= replace(line, "^ *" => "") end # directly remove leading space characters
            if(contains(line, "</help>")) record = false end
        end
    end
    description = replace(description, "<help>" => "")
    description = replace(description, "</help>" => "")
    description = replace(description, "<![CDATA[" => "")
    description = replace(description, "]]>" => "")
    description = replace(description, "**What it does**" => "")
    description = replace(description, r"(http[^ \r\n]+)" => s"<a href='\1'>\1</a>")
    return description
end

# Log messages with trace (set die = 1 to stop the process, default is 0)
function die(message::String)
    @error "$message"
    # print the stacktrace
    stacktrace()
    exit(1)
end

function die(messageParts::Vector{String})
    die(join(messageParts, " "))
end

function archiveFile(writer::ZipFile.Writer, filepath::String, subpath::String = "")
    f = open(filepath, "r")
    content = read(f, String)
    close(f)
    path = subpath == "" ? basename(filepath) : string(subpath, "/", basename(filepath))
    zf = ZipFile.addfile(writer, path, method = ZipFile.Deflate);
    write(zf, content)
end

function archive(zipFile::String, files::Vector{String})
    w = ZipFile.Writer(zipFile)
    for filepath in files
        if Base.Filesystem.isfile(filepath)
            archiveFile(w, filepath)
        end
    end
    close(w)
end

function getParams(json::Dict{String, Any}, inputFileName::String)
    input = InputFile(json["inputFile"], inputFileName, json["sheetNumber"], json["headerLine"])
    idType = json["idType"]
    hasSites = json["type"]["value"]
    stats = json["type"]["statistics"]["value"]
    idColumn = json["type"]["statistics"]["col_id"]
    idSite = hasSites ? json["type"]["statistics"]["col_site"] : ""
    idPvalue = stats != "none" ? json["type"]["statistics"]["col_pvalue"] : ""
    idTukey = stats == "conditions" ? json["type"]["statistics"]["col_tukey"] : ""
    idFc = (stats == "pvalue_fc" || stats == "conditions") ? json["type"]["statistics"]["col_fc"] : ""
    columns = Columns(idColumn, idSite, idPvalue, idTukey, idFc)
    conditions = stats == "conditions" ? map(c -> string(c), unique(split(json["type"]["statistics"]["conditions"], "__cn__"))) : Vector{String}()
    thresholds = Thresholds(json["thresholds"]["pvalue"], json["thresholds"]["tukey"], json["thresholds"]["fc"])
    return Params(input, idType, hasSites, stats, columns, conditions, thresholds)
end

function getFirstColumnNumber(params::Params)::Int64
    columns = [params.columns.id, params.columns.site, params.columns.pvalue, params.columns.tukey, params.columns.fc]
    ids = getColumnId(filter(c -> c != "", columns))
    return (isempty(ids) ? 0 : sort(ids)[1])
end

function estimateNbConditions(params::Params, nbColumns::Int64)::Int64
    return (nbColumns - (params.hasModificationSites ? 2 : 1) - getFirstColumnNumber(params)) / 2
end

function getConditions(params::Params, headerLine::XLSX.SheetRow)::Vector{String}
    # conditions = Dict{Int64, String}
    conditions = Vector{String}()
    # there might be no condition at all
    if(params.hasConditions)
        # get columns boundaries
        col1, coln = XLSX.column_bounds(headerLine) # returns something like (1, 59)
        # determine the number of conditions in the file
        nbConditions = estimateNbConditions(params, coln - col1 + 1)
        # use the given conditions if their number fits the number of conditions
        userConditions = params.conditionLabels
        if(length(userConditions) != nbConditions)
            # if the conditions are not provided or do not fit the actual number of conditions
            # then try to get the headers from the input file, but they have to be unique
            userConditions = Vector{String}()
            start = min(getColumnId(params.columns.tukey), getColumnId(params.columns.fc))
            for i in start:2:coln
                push!(userConditions, headerLine[i])
            end
            unique!(userConditions)
        end
        # only use the conditions if their number corresponds to the expected number
        if(length(userConditions) == nbConditions) conditions = userConditions
        # otherwise use default conditions
        else conditions = map(i -> "Condition $i", 1:nbConditions) end
    end
    return conditions
end

function looksLikeUniProt(identifier::String)::Bool
    # allow accession numbers as defined in https://www.uniprot.org/help/accession_numbers
    # examples: A2BC19, P12345, A0A023GPI8
    return if(match(r"^[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2}$", identifier) !== nothing) true
    # allow swissprot entry names, as defined in https://www.uniprot.org/help/entry_name
    # examples: INS_HUMAN, INS1_MOUSE, INS2_MOUSE
    elseif(match(r"^[A-Z0-9]{1,5}_[A-Z0-9]{1,5}$", identifier) !== nothing) true
    # allow trembl entry names, as defined in https://www.uniprot.org/help/entry_name
    # examples: A2BC19_HELPX, P12345_RABIT, A0A023GPI8_CANBL
    elseif(match(r"^[A-Z0-9]{1,5}_[A-Z0-9]{1,5}$", identifier) !== nothing) true
    else false end
end

function getScore(row::XLSX.SheetRow, column::String)::Float64
    if(column == "") return NaN
    else
        score = row[column]
        return typeof(score) <: Float64 ? score : NaN
    end
end

function isValid(value, threshold::Float64)::Bool
    return typeof(value) <: Float64 && value < threshold
end

function getCurrentStatusId(params::Params, pvalue, tukey, fc)::Int64 # value types are not requested, in case there is a NaN or a Missing value
    return if(params.statistics == "pvalue" && isValid(pvalue, params.thresholds.pvalue)) OK
    elseif(params.statistics == "pvalue_fc" && isValid(pvalue, params.thresholds.pvalue))
        if(typeof(fc) <: Float64 && fc > params.thresholds.fc) UP
        elseif(typeof(fc) <: Float64 && fc < params.thresholds.fc * -1) DO
        else OK end
    elseif(params.hasConditions && isValid(pvalue, params.thresholds.pvalue) && isValid(tukey, params.thresholds.tukey))
        if(typeof(fc) <: Float64 && fc > params.thresholds.fc) UP
        elseif(typeof(fc) <: Float64 && fc < params.thresholds.fc * -1) DO
        else OK end
    else KO end
end

function getStatusIds(params::Params, row::XLSX.SheetRow, nbConditions::Int64)::LittleDict{Int64, Int64}
    statusIds = LittleDict{Int64, Int64}()
    pvalue = getScore(row, params.columns.pvalue)
    if(params.hasConditions)
        # get the first tukey and fc column number
        cTu = params.columns.tukey
        cFc = params.columns.fc
        # loop on each condition
        for i in 1:nbConditions
            tukey = row[getColumnId(cTu) + (i - 1) * 2]
            fc = row[getColumnId(cFc) + (i - 1) * 2]
            statusIds[i] = getCurrentStatusId(params, pvalue, tukey, fc)
        end
    else
        # use a default condition that will not be shown
        tukey = getScore(row, params.columns.tukey)
        fc = getScore(row, params.columns.fc)
        statusIds[1] = getCurrentStatusId(params, pvalue, tukey, fc)
    end
    return statusIds
end

# isNotNull(value::String)::Bool = !ismissing(value) && !isnan(value) && value != ""
isNotNull(value)::Bool = typeof(value) <: String && value != ""

function getEntries(params::Params, row::XLSX.SheetRow, conditions::Vector{String})::Vector{Entry}
    entries = Vector{Entry}()
    # get the id and the site, or use a default site eventually
    id = row[params.columns.id]
    site = (params.hasModificationSites ? string(row[params.columns.site]) : "")
    # do not continue if the id or the site is missing
    if(isNotNull(id) && (isNotNull(site) || !params.hasModificationSites))
        # get the status on the fly (it returns one status id per condition)
        statusIds = getStatusIds(params, row, length(conditions))
        for i in eachindex(statusIds)
            push!(entries, Entry(id, site, params.hasConditions ? conditions[i] : "", statusIds[i], ""))
        end
    end
    return entries
end

function getKey(params::Params, entry::Entry)::String
    return params.hasModificationSites ? "$(entry.id) at site $(entry.site)" : entry.id
end

function extractData(params::Params)::Pair{Ref{Vector{Entry}}, Ref{Dict{String, Int64}}}
    entries = Vector{Entry}()
    conditions = Vector{String}()
    duplicates = Dict{String, Int64}()
    nbRows = 0
    XLSX.openxlsx(params.input.path, enable_cache = false) do xf
        sheet = xf[params.input.sheetNumber]
        # read each lien
        for row in XLSX.eachrow(sheet)
            nbRows += 1
            ln = XLSX.row_number(row)
            if(ln == params.input.headerLine) # get the headers
                conditions = getConditions(params, row)
            elseif(ln > params.input.headerLine) # get the data
                currentEntries = getEntries(params, row, conditions)
                if(!isempty(currentEntries))
                    key = getKey(params, currentEntries[1])
                    if(count(e -> getKey(params, e) == key, entries) == 0)
                        append!(entries, currentEntries)
                    else
                        if(!haskey(duplicates, key)) duplicates[key] = 0 end
                        duplicates[key] += 1
                    end
                end
            end
        end
    end
    nbEntries = length(unique(map(e -> getKey(params, e), entries)))
    # println("$nbRows rows have been read, containing $nbEntries entries and $(length(duplicates)) duplicates")
    @info "$nbRows rows have been read, containing $nbEntries entries and $(length(duplicates)) duplicates"
    # check if uniprot ids look like uniprot ids
    if(params.isUniprot)
        maxNotLikeUniprot = 10
        if(count(e -> !looksLikeUniProt(e.id), entries) > maxNotLikeUniprot)
            die("Too many protein identifiers are not UniProt identifiers, please only use Accession numbers or Entry names")
        end
    end
    # return the entries
    return Pair(Ref(entries), Ref(duplicates))
end

function searchUniprotEntries(entriesRef::Ref{Vector{Entry}})
    ids = map(e -> e.id, entriesRef[])
    mapping = idmapping("UniProtKB_AC-ID", "UniProtKB", "", Ref(ids))[]
    for key in collect(keys(mapping))
        for entry in filter(e -> e.id == key, entriesRef[])
            entry.uniprotIdentifier = mapping[key][1]
        end
    end
end

function getWorthyEntries(params::Params, entriesRef::Ref{Vector{Entry}})::Ref{Vector{Entry}}
    entries = Vector{Entry}()
    # get the list of unique keys (one per row in the file)
    keys = unique(map(e -> getKey(params, e), entriesRef[]))
    # for each key, there must be at least one non-KO condition
    for key in keys
        subset = filter(e -> getKey(params, e) == key, entriesRef[])
        if(count(e -> e.statusId != KO, subset) > 0) append!(entries, subset) end
    end
    # return all the entries that match this constraint
    return Ref(entries)
end

function addPathways(params::Params, genesRef::Ref{Vector{Gene}})
    relations = Dict{String, Vector{String}}()
    # get the list of organisms
    # organisms = unique(map(g -> g.organism, genesRef[]))
    organisms = params.isUniprot ? unique(map(g -> g.organism, genesRef[])) : ["compound"]
    # search kegg for all the kegg ids and relations for each organism
    for org in organisms
        for line in split(REST_GET("$KEGG_URL/link/pathway/$org"), "\n")
            # returns lines formatted as: "hsa:6484\tpath:hsa01100" or "cpd:C00022\tpath:map00010"
            if(contains(line, "\t"))
                geneid, pathway = split(line, "\t")
                if(contains(geneid, "cpd:")) geneid = replace(geneid, "cpd:" => "") end
                if(contains(pathway, "path:")) pathway = replace(pathway, "path:" => "") end
                if(!haskey(relations, geneid)) relations[geneid] = Vector{String}() end
                push!(relations[geneid], pathway)
            end
        end
    end
    # add the relations for each pathway from the input data
    for gene in genesRef[]
        if(haskey(relations, gene.id)) # should always be true
            gene.pathwaysIds = relations[gene.id]
        end
    end
end

function getKeggData(params::Params, entriesRef::Ref{Vector{Entry}})::Ref{Vector{Gene}}
    # println("Get the updated list of Kegg data")
    @info "Get the updated list of Kegg data"
    genes = Dict{String, Gene}()
    # get the entries for which we want to get the genes
    worthyEntries = getWorthyEntries(params, entriesRef)[]
    # convert all these ids to kegg ids
    ids = unique(map(e -> e.uniprotIdentifier != "" ? e.uniprotIdentifier : e.id, worthyEntries))
    if(params.isUniprot)
        maxNbIds = 100
        for start in 1:maxNbIds:length(ids)
            # search a subset of the ids
            stop = min(start + maxNbIds, length(ids))
            # format the URL (ie. https://rest.kegg.jp/conv/genes/uniprot:Q96QH8+uniprot:P12345)
            mappedIds = map(id -> "uniprot:$id", ids[start:stop])
            url = string("$KEGG_URL/conv/genes/", join(mappedIds, "+"))
            # store the kegg ids on the fly
            for line in split(REST_GET(url), "\n")
                # returns lines formatted as: "up:Q96QH8\thsa:729201"
                if(match(r".+:.+\t.+:.+$", line) !== nothing)
                    input, output = map(s -> string(s), split(line, "\t"))
                    if(contains(input, ":")) input = replace(input, r".*:" => "") end
                    if(!haskey(genes, output))
                        genes[output] = Gene(output)
                    end
                    push!(genes[output].entryIds, input) # add the input id
                end
            end
        end
    else
        for id in ids
            gene = Gene(id)
            gene.entryIds = [id]
            genes[id] = gene
        end
    end
    # get the genes only
    genesRef = Ref(collect(values(genes)))
    # search information per organisms
    addPathways(params, genesRef)
    # return the genes
    return genesRef
end

function getNbDaysSinceLastModification(file::String)::Int64
    currentDate = DateTime(today())
    lastUpdatedTime = unix2datetime(stat(file).mtime)
    return Dates.value(round(currentDate - lastUpdatedTime, Day(1)))
end

function isFileUpdadeRequired(pathwayId::String)::Bool
    return if(FORCE_UPDATE) true # there is a static option to force update, just for test purpose
    elseif(!isfile(getConfFile(pathwayId))) true # if the file is missing, the update is needed
    elseif(!isfile(getPngFile(pathwayId))) true # if the file is missing, the update is needed
    elseif(!isfile(getInfoFile(pathwayId))) true # if the file is missing, the update is needed
    elseif(getNbDaysSinceLastModification(getConfFile(pathwayId)) > CACHE_MAX_AGE_IN_DAYS) true # if the conf file is too old (any file would do)
    else false end # in any other case, no need for an update
end

function downloadPathway(pathwayId::String, type::String, outputFile::String)
    # download to a temporary file
    ext = if(type == "image") "png" elseif(type == "") "txt" else "conf" end
    tempFile = string(TEMP_DIRECTORY, "temp.$ext")
    Base.download("$KEGG_URL/get/$pathwayId/$type", tempFile)
    try
        Base.download("$KEGG_URL/get/$pathwayId/$type", tempFile)
    catch _
        # the pathway may have been stripped from its organism
        Base.download("$KEGG_URL/get/map$pathwayId/$type", tempFile)
    end
    # if the download has failed again, the exception should kill everything
    mv(tempFile, outputFile, force = true)
end

function updateKeggFile(pathwayId::String)
    # println("Updating files related to pathway $pathwayId")
    @info "Updating files related to pathway $pathwayId"
    # download all the required files for this pathway
    downloadPathway(pathwayId, "", getInfoFile(pathwayId))
    downloadPathway(pathwayId, "conf", getConfFile(pathwayId))
    downloadPathway(pathwayId, "image", getPngFile(pathwayId))
    # wait for a second, to reduce the amount of requests
    sleep(1)
    # in the Perl version, there was a check because the download of the image could fail
    # but it was likely because of the library
end

function getPathway(infoFile::String)::Pathway
    data = Dict{String, Vector{String}}()
    open(infoFile, "r") do reader
        tag = ""
        while !eof(reader)
            line = readline(reader)
            if(line != "" && line != "///")
                # extract the tag if there is one, otherwise keep the previous one
                if(startswith(line, r"[A-Z]+")) tag = replace(line, r" .*" => "") end
                # do not store this kind of data
                if(tag != "REFERENCE" && tag != "NETWORK")
                    # create an empty array on new tags
                    if(!haskey(data, tag)) data[tag] = Vector{String}() end
                    # content may have two columns
                    content = replace(line, r"^[A-Z]+ *" => "")
                    if(contains(content, "  "))
                        push!(data[tag], replace(content, r"  +" => " [") * "]")
                    else push!(data[tag], content) end
                end
            end
        end
    end
    pathwayId = if(haskey(data, "ENTRY")) string(split(data["ENTRY"][1], " ")[1])
    else splitext(last(splitpath(infoFile)))[1] end
    name = (haskey(data, "NAME") ? data["NAME"][1] : pathwayId)
    return Pathway(pathwayId, name, data)
end

function downloadUpdateGenerate(params::Params, entriesRef::Ref{Vector{Entry}}, genesRef::Ref{Vector{Gene}}, tempDirectory::String = TEMP_DIRECTORY)::Ref{Vector{Pathway}}
    # println("Update the required files and generate the corresponding HTML files")
    @info "Update the required files and generate the corresponding HTML files"
    pathways = Vector{Pathway}()
    # get the list of pathways to consider
    ids = Vector{String}()
    for gene in genesRef[]
        append!(ids, gene.pathwaysIds)
    end
    unique!(ids)
    total = length(ids)
    # loop on each kegg entry
    for i in eachindex(ids)
        id = ids[i]
        # @info "> Managing identifier $id ($i/$total)"
        # download the corresponding files if they are missing or too old
        if(isFileUpdadeRequired(id)) updateKeggFile(id) end
        # check that all the required files are present before going further
        confFile = getConfFile(id)
        infoFile = getInfoFile(id)
        pngFile = getPngFile(id)
        if(isfile(confFile) && isfile(infoFile) && isfile(pngFile))
            # extract information for this pathway
            pathway = getPathway(infoFile)
            push!(pathways, pathway)
            # generate the HTML file
            createHtmlFile(params, pathway, confFile, pngFile, entriesRef, genesRef, tempDirectory)
        end
        # show progression every 50 id
        if(i % 50 == 0) @info "$i/$total pathways have been treated" end
        # if(i != length(ids)) sleep(1) end
    end
    @info "$total HTML files have been generated, returning the corresponding pathway maps"
    return Ref(pathways)
end
