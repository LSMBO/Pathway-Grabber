UNIPROT_REST_URL = "https://rest.uniprot.org"
DEFAULT_MAX_WAIT_TIME = 120
DEFAULT_SLEEP = 1

function REST_GET_generic(url::String, requestedHeaders = Vector{String}[])::Pair{String, Dict{String, String}}
    response = HTTP.get(url, decompress = false)
    if response.status == 200
        headers = Dict{String, String}()
        for header in response.headers
            if count(rh -> rh == header.first, requestedHeaders) > 0 push!(headers, header) end
        end
        return Pair(String(response.body), headers)
    else
        status = response.status
        message = String(response.body)
        die("HTTP GET error code:$status with message: $message.\nDownloaded URL was: $url")
    end
end

function REST_GET(url::String)::String
    return REST_GET_generic(url).first
end
function getUniprotRelease()::String
    results = REST_GET_generic("$UNIPROT_REST_URL/uniprotkb/P12345.fasta", ["X-UniProt-Release", "X-UniProt-Release-Date"])
    return results.second["X-UniProt-Release"]
end

function sendGetRequest(url::String)::HTTP.Messages.Response
    time = 0
    while time <= DEFAULT_MAX_WAIT_TIME
        response = HTTP.get(url, decompress = false)
        if response.status == 200
            # The 200 OK status code indicates the request succeeded.
            return response
        else
            if timer != 0
                @warn "The request failed with error $(response->code) ($(String(response->body))) and will be run again in a few seconds"
            end
            timer += 10
            sleep(10)
        end
    end
    die("The request has failed too many times and will not be tried anymore. The URL was: $url")
end

function getHeader(response, header::String)
    return if(HTTP.hasheader(response, header)) string(HTTP.headers(response, header)[1]) else nothing end
end

# sends the request for idmapping
function submit_id_mapping(from::String, to::String, taxonId::String, ids::Vector{String})::String
    # prepare parameters for the POST request
    params = Dict{String, String}("from" => from, "to" => to, "ids" => join(ids, ","))
    if taxonId !== nothing && taxonId != "" params["taxId"] = taxonId end

    # send the request to uniprot
    response = HTTP.post("$UNIPROT_REST_URL/idmapping/run"; body = HTTP.Form(params))
    if response.status == 200
        return JSON.parse(String(response.body))["jobId"]
    else
        status = response.status
        message = String(response.body)
        die("HTTP GET error code:$status with message: $message.\nDownloaded URL was: $url")
    end
end

# checks the status of the job
function check_id_mapping_results_ready(jobId::String)::Bool
    jobStatus = ""
    timer = 0
    while jobStatus != "FINISHED" && timer <= DEFAULT_MAX_WAIT_TIME
        if timer > 0
            sleep(DEFAULT_SLEEP)
            timer += DEFAULT_SLEEP
        end
        response = sendGetRequest("$UNIPROT_REST_URL/idmapping/status/$jobId")
        json = JSON.parse(String(response.body))
        jobStatus = if haskey(json, "jobStatus") json["jobStatus"] else "FINISHED" end
    end
    return jobStatus == "FINISHED"
end

# get the link of the first page of the results
function get_id_mapping_results_link(jobId::String)::String
    response = sendGetRequest("$UNIPROT_REST_URL/idmapping/details/$jobId")
    return JSON.parse(String(response.body))["redirectURL"]
end

# get the link of the next page of the results
function get_next_link(response)
    link = getHeader(response, "Link")
    if(link !== nothing)
        m = match(r"<(.+)>; rel=\"next\"", link)
        if m !== nothing link = string(m.captures[1]) end
    end
    return link
end

# get all the results, page by page
function get_id_mapping_results_search(url::String)::Dict{String, Vector{String}}
    mappedIds = Dict{String, Vector{String}}()
    while url !== nothing
        response = sendGetRequest(url)
        json = JSON.parse(String(response.body))
        for output in json["results"]
            before = output["from"]
            after = output["to"]["primaryAccession"]
            if(!(before in keys(mappedIds))) mappedIds[before] = Vector{String}() end
            push!(mappedIds[before], after)
        end
        url = get_next_link(response)
    end
    return mappedIds
end

# runs a full idmapping on all the given ids
function idmapping_unit(from::String, to::String, taxonId::String, ids::Vector{String})::Dict{String, Vector{String}}
    map = Dict{String, Vector{String}}()
    jobId = submit_id_mapping(from, to, taxonId, ids)
    if check_id_mapping_results_ready(jobId)
        link = get_id_mapping_results_link(jobId)
        map = get_id_mapping_results_search(link)
    end
    return map
end

# from: the database of the input ids
# to: the database requested
# taxonId: the taxonomy id if required (ie. for gene name) ; use undef if no taxonomy id is needed
# ids: an array of ids
function idmapping(from::String, to::String, taxonId::String, idsRef::Ref{Vector{String}})::Ref{Dict{String, Vector{String}}}
    ids = idsRef[]
    # prepare a Dict to store the results
    mappedIds = Dict{String, Vector{String}}()
    # avoid the hard limitation of 100000 max ids per request
    maxNbIds = 85000
    for start in 1:maxNbIds:length(ids)
        # run id mapping for this subset
        stop = min(start + maxNbIds, length(ids))
        mapping = idmapping_unit(from, to, taxonId, ids[start:stop])
        # add the results to the main output
        mappedIds = merge(mappedIds, mapping)
    end
    return Ref(mappedIds)
end
