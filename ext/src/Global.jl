KEGG_URL = "https://rest.kegg.jp"
KEGG_WWW = "https://rest.kegg.jp"
CACHE_MAX_AGE_IN_DAYS = 2 * 30 # 2 months
FORCE_UPDATE = false

CONF_DIRECTORY = string(@__DIR__, "/../conf/")
INFO_DIRECTORY = string(@__DIR__, "/../info/")
MAPS_DIRECTORY = string(@__DIR__, "/../maps/")
TEMP_DIRECTORY = string(@__DIR__, "/../temp/")

getConfFile(pathwayId::String)::String = string(CONF_DIRECTORY, "$pathwayId.conf")
getPngFile(pathwayId::String)::String = string(MAPS_DIRECTORY, "$pathwayId.png")
getInfoFile(pathwayId::String)::String = string(INFO_DIRECTORY, "$pathwayId.txt")
getHtmlFile(tempDirectory::String, pathwayId::String)::String = string(tempDirectory, "/$pathwayId.html")

# status ids
KO = 1
OK = 2
UP = 3
DO = 4

struct Status
    id::Int64
    code::String
    text::String
    color::String
    symbol::String
    html::String
    description::String
    Status(_id::Int64, _code::String, _text::String, _color::String, _symbol::String, _html::String, _desc::String) = new(_id, _code, _text, _color, _symbol, _html, _desc)
    Status() = new(0, "NA", "", "", "", "", "") # default empty status that should never be used
end

STATUS = LittleDict{Int64, Status}()
STATUS[KO] = Status(KO, "KO", "Non significant", "#ffe333", "\\2716", "&#10006;", "Does not satisfy statistical criteria") # yellow
STATUS[OK] = Status(OK, "OK", "Significant", "#428fd3", "\\2714", "&#10004;", "Satisfies statistical criteria") # blue
STATUS[UP] = Status(UP, "UP", "Upregulated", "#ff4c33", "\\2191", "&#8593;", "Satisfies statistical criteria, the protein is upregulated") # red
STATUS[DO] = Status(DO, "DO", "Downregulated", "#53c326", "\\2193", "&#8595;", "Satisfies statistical criteria, the protein is downregulated") # green

function getStatus(id::Int64)::Status
    return (haskey(STATUS, id) ? STATUS[id] : Status())
end

function getStatus(code::String)::Status
    matches = filter(st -> st.code == code, collect(values(STATUS)))
    return (length(matches) > 0 ? matches[1] : Status())
end

struct InputFile
    path::String
    name::String
    sheetNumber::Int64
    headerLine::Int64
    InputFile(_path::String, _name::String, _sheet::Int64, _hline::Int64) = new(_path, _name, _sheet, _hline)
    InputFile(_path::String, _name::String, _sheet::Int32, _hline::Int32) = new(_path, _name, _sheet, _hline)
    InputFile() = new("", "", 1, 1) # for test purpose
end

struct Columns
    id::String # default: A
    site::String # default: B
    pvalue::String # default: C
    tukey::String # default: D
    fc::String # default: E
    Columns(a::String, b::String, c::String, d::String, e::String) = new(uppercase(a), uppercase(b), uppercase(c), uppercase(d), uppercase(e))
    Columns() = new("", "", "", "", "") # for test purpose
end

struct Thresholds
    pvalue::Float64 # default: 0.05
    tukey::Float64 # default: 0.05
    fc::Float64 # default: 1.5
    Thresholds(p::Float64, t::Float64, f::Float64) = new(p, t, f)
    Thresholds() = new(0.0, 0.0, 0.0) # for test purpose
end

struct Params
    useGui::Bool # default: false
    input::InputFile
    idType::String # uniprot, uniprotcheck or kegg
    isUniprot::Bool # if idType is uniprot or uniprotcheck
    hasModificationSites::Bool # if true, unicity is based on Pair(protein, site) instead of just the protein
    statistics::String # none, pvalue, pvalue_fc or conditions
    columns::Columns
    hasConditions::Bool # only if conditionLabels is not empty
    conditionLabels::Vector{String} # they have to fit the number of conditions in the file
    thresholds::Thresholds
    indicateStatus::Bool
    Params(_input::InputFile, _idType::String, _hasSites::Bool, _stats::String, _columns::Columns, _conditions::Vector{String}, _thresholds::Thresholds) = new(false, _input, _idType, (_idType == "uniprot" || _idType == "uniprotcheck"), _hasSites, _stats, _columns, !isempty(_conditions), _conditions, _thresholds, _stats != "none")
end

mutable struct Entry
    const id::String
    const site::String
    const condition::String
    const statusId::Int64
    uniprotIdentifier::String # may be different from the identifier
end

# Pathway ids are like "hsa00040"
struct Pathway
    id::String
    name::String
    # LittleDict are OrderedDict that are very fast for short collections
    data::LittleDict{String, Vector{String}}
end

# Gene ids are like "hsa:51181"
mutable struct Gene
    const id::String
    const organism::String
    pathwaysIds::Vector{String}
    entryIds::Vector{String}
    # Gene(_id::String, _org::String) = new(_id, _org, Vector{String}(), Vector{String}())
    Gene(_id::String) = new(_id, split(_id, ":")[1], Vector{String}(), Vector{String}())
    Gene(_id::String, _pathwaysIds::Vector{String}, _entryIds::Vector{String}) = new(_id, split(_id, ":")[1], _pathwaysIds, _entryIds)
end

struct Point
    x::Number
    y::Number
end
