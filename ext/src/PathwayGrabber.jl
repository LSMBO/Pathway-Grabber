module PathwayGrabber

export runFromGui

using Base64, Combinatorics, Dates, DelimitedFiles, GZip, HTTP, Images, JSON, OrderedCollections, Test, XLSX, ZipFile
include(string(@__DIR__, "/Log.jl"))
include(string(@__DIR__, "/Global.jl"))
include(string(@__DIR__, "/Request.jl"))
include(string(@__DIR__, "/Xlsx.jl"))
include(string(@__DIR__, "/HtmlMaker.jl"))
include(string(@__DIR__, "/Common.jl"))

# function run(json::Dict{String, Any}, inputFileName::String, generateTsvFiles::Bool = false, cleanTempDir::Bool = true)::Tuple{String, String}
function run(json::Dict{String, Any}, inputFileName::String, generateTsvFiles::Bool = false, cleanTempDir::Bool = true)::String
    # log as soon as possible
    @info "Starting PathwayGrabber with parameters $json"
    # create a temp folder, mostly for the future GUI
    tempDir = mktempdir(TEMP_DIRECTORY; cleanup = cleanTempDir)
    if(cleanTempDir) @info "Job temporary directory: $tempDir" else @info "Job directory: $tempDir (will NOT be deleted automatically at the end of the process)" end
    # get the parameters
    params = getParams(json, inputFileName)
    # extract data from the input file
    entriesRef, duplicatesRef = extractData(params)
    # make sure the uniprot identifiers are the good ones
    # what is expected is the Entry, and not the Entry name (ie. P0DPI2 instead of GAL3A_HUMAN)
    if(params.isUniprot) searchUniprotEntries(entriesRef) end

    # get information from KEGG
    genesRef = getKeggData(params, entriesRef)
    # update the kegg files older than n months and generate html files
    pathwaysRef = downloadUpdateGenerate(params, entriesRef, genesRef, tempDir)
    # archive the html files
    # zipFile = "PathwayGrabber-HTML.zip"
    # archive(zipFile, filter(f -> isfile(f) && endswith(f, ".html"), readdir(tempDir, join = true)))

    # write the excel output file
    # xlsxFile = writeExcelOutput(params, entriesRef, genesRef, pathwaysRef, duplicatesRef, tempDir, generateTsvFiles)
    writeExcelOutput(params, entriesRef, genesRef, pathwaysRef, duplicatesRef, tempDir, generateTsvFiles)

    # return the generated files
    # return (xlsxFile, zipFile)
    return tempDir
end

function runFromCmd(args::Vector{String}, generateTsvFiles::Bool = false, cleanTempDir::Bool = true)
    # get the parameters, they should all be there
    input = args[1]
    sheet = parse(Int64, args[2])
    line = parse(Int64, args[3])
    type = args[4]
    hasModificationSites = args[5] == "true"
    content, idCol, siteCol, pvalCol, tukeyCol, fcCol, conds = args[6:12]
    pvalThreshold = parse(Float64, args[13])
    tukeyThreshold = parse(Float64, args[14])
    fcThreshold = parse(Float64, args[15])

    # put the parameters into a json that will work later
    statistics = Dict("value" => content, "col_id" => idCol)
    if(hasModificationSites) statistics["col_site"] = siteCol end
    if(content != "none") statistics["col_pvalue"] = pvalCol end
    if(content == "pvalue_fc") statistics["col_fc"] = fcCol end
    if(content == "conditions")
        statistics["col_tukey"] = tukeyCol
        statistics["col_fc"] = fcCol
        statistics["conditions"] = conds
    end
    json = Dict{String, Any}("inputFile" => input, "sheetNumber" => sheet, "headerLine" => line, "idType" => type, 
    "type" => Dict("value" => hasModificationSites, "statistics" => statistics), 
    "thresholds" => Dict("pvalue" => pvalThreshold, "tukey" => tukeyThreshold, "fc" => fcThreshold)
    )
    # run the main command
    tempDirectory = run(json, basename(input), generateTsvFiles, cleanTempDir)
    # archive data for later export
    zipFile = string("$tempDirectory/PathwayGrabber.zip")
    @info "Compress the output data into $zipFile"
    archive(zipFile, filter(f -> isfile(f) && (endswith(f, ".html") || endswith(f, ".xlsx")), readdir(tempDirectory, join = true)))
    # print the output directory so ElectronJS can read it properly
    println("ENDOFPROCESS - Data have been generated in: $(tempDirectory)")
end

function runFromGui(args::Vector{String})
    runFromCmd(args, true, false)
end

function runFromGalaxy(args::Vector{String})
    # get the input
    paramFile = args[1]
    inputFileName = args[2]
    outputFile = args[3]
    zipFile = args[4]
    # call the main app
    # tempXlsxFile, tempZipFile = run(JSON.parsefile(paramFile), inputFileName)
    tempDir = run(JSON.parsefile(paramFile), inputFileName)
    # get the output files
    tempZipFile = "PathwayGrabber-HTML.zip"
    archive(tempZipFile, filter(f -> isfile(f) && endswith(f, ".html"), readdir(tempDir, join = true)))
    tempXlsxFile = filter(f -> isfile(f) && endswith(f, ".xlsx"), readdir(tempDir, join = true))[1]
    # move and clean the output files to their final destination
    mv(tempXlsxFile, outputFile, force = true)
    mv(tempZipFile, zipFile, force = true)
    # declare that it finished ok
    @info "Correct ending of the script"
end

if(length(ARGS) == 4) runFromGalaxy(ARGS) 
elseif(length(ARGS) > 0) runFromGui(ARGS);
end
return 0

#=
@testset "PathwayGrabber-Global" begin
    @test endswith(getConfFile("test"), "/test.conf")
    @test endswith(getPngFile("test"), "/test.png")
    @test endswith(getInfoFile("test"), "/test.txt")
    @test getHtmlFile(".", "test") == "./test.html"

    @test getStatus(0) == Status()
    @test getStatus(KO).code == "KO"
    @test getStatus("") == Status()
    @test getStatus("KO").code == "KO"
end

@testset "PathwayGrabber-Html" begin
    inputFile = string(@__DIR__, "/../test_data/kegg-uniprot.xlsx")
    conditions = Vector{String}()
    for i in 1:28 push!(conditions, "My-Condition-$i") end
    json = Dict{String, Any}("inputFile" => inputFile, "sheetNumber" => 1, "headerLine" => 1, "idType" => "uniprot", "type" => Dict("value" => false, "statistics" => Dict("value" => "conditions", "col_id" => "B", "col_pvalue" => "C", "col_tukey" => "D", "col_fc" => "E", "conditions" => join(conditions, "__cn__"))), "thresholds" => Dict("pvalue" => 0.05, "tukey" => 0.05, "fc" => 1.5))
    params = getParams(json, "kegg-uniprot.xlsx")

    combinations = getCombinations()
    @test length(combinations) == 15
    @test count(c -> length(c) == 2, combinations) == 4
    @test count(c -> length(c) == 5, combinations) == 6
    @test count(c -> length(c) == 8, combinations) == 4
    @test count(c -> length(c) == 11, combinations) == 1

    css = makeCss("")
    @test length(css) == 62

    imgFile = string(@__DIR__, "/../test_data/kegg-hsa01040.png")
    img = getImage(imgFile)
    @test startswith(img, "<img width=\"1398px\" height=\"1391px\" src=\"data:image/png;base64,")
    @test length(img) == 61311

    @test length(getLegend(params, "")) == 15

    @test format("test", "value") == "value"
    @test format("ENTRY", "hsa01040 [Pathway]") == "<a href='https://www.kegg.jp/entry/hsa01040' target='_blank'>hsa01040 [Pathway]</a>"
    @test format("PATHWAY_MAP", "hsa01040 [Pathway]") == "<a href='https://www.kegg.jp/pathway/hsa01040' target='_blank'>hsa01040 [Pathway]</a>"

    data = LittleDict{String, Vector{String}}()
    data["ENTRY"] = ["hsa01040 [Pathway]"]
    data["COMPOUND"] = ["C00154 [Palmitoyl-CoA]", "C00219 [Arachidonate]"]
    pathway = Pathway("hsa01040", "Biosynthesis of unsaturated fatty acids - Homo sapiens (human)", data)
    info = getInfo(pathway, "")
    @test length(info) == 5

    html1 = getHtmlStartOfFile(params, pathway, imgFile)
    @test length(html1) == 10 + 62 + 15 + 5

    @test isCircle("circ (1198,552) 4") == true
    @test isCircle("filled_circ (462,986) 4") == true
    @test isCircle("rect (40,45) (388,70)") == false
    @test isLine("line (107,231,107,243) 1") == true
    @test isPolygon("poly (107,243,103,234,107,237,110,234)") == true
    @test isPolygon("line (107,231,107,243) 1") == false
    @test isRectangle("rect (40,45) (388,70)") == true

    @test getPoints("(541,878)") == [Point(541, 878)]
    @test getPoints("(107,231,107,243)") == [Point(107, 231), Point(107, 243)]
    @test getPoints("(541,878)", true) == [Point(541 + TRANSLATE, 878 + TRANSLATE)]

    @test getCircleStyle("circ (541,878) 4") == "left:$(539 + TRANSLATE).0px;top:$(876 + TRANSLATE).0px;width:4px;height:4px;"
    @test getRectangleStyle("rect (40,45) (388,70)") == "left:$(40 + TRANSLATE)px;top:$(45 + TRANSLATE)px;width:348px;height:25px"
    @test getTopLeftWidthHeight([Point(107, 243), Point(103, 234), Point(107, 237), Point(110, 234)]) == [234, 103, 7, 9]
    @test getLineStyle("line (107,231,107,243) 1") == "top:$(231 + TRANSLATE)px;left:$(107 + TRANSLATE)px;width:0px;height:12px;clip-path:path('M 2,2 L 2,14 L 4,16 L 4,4 Z');"

    @test isapprox(getDistance(Point(1, 1), Point(10, 10)), 12.728; atol = 0.001)
    @test isapprox(getTotalDistance(Point(10, 10), Point(1, 1), Point(20, 10), Point(10, 20)), 32.728; atol = 0.001)
    @test arrowToTriangle([Point(107, 243), Point(107, 237), Point(110, 234)]) == [Point(107, 243), Point(107, 237), Point(110, 234)]
    @test arrowToTriangle([Point(107, 243), Point(103, 234), Point(107, 237), Point(110, 234)]) == [Point(107, 243), Point(103, 234), Point(110, 234)]
    @test getPointsAtADistance(3.0, 7.0, Point(12, 34), 10.0) == [Point(6.27, 25.81), Point(12.33, 43.99)]
    @test getSide(Point(5, 5), Point(0, 0), Point(10, 10)) == 0
    @test getSide(Point(3, 7), Point(0, 0), Point(10, 10)) < 0
    @test getSide(Point(7, 3), Point(0, 0), Point(10, 10)) > 0
    @test transformArrowSummit(Point(107, 243), Point(103, 234), Point(110, 234)) == Point(107.11, 244.98)
    @test transformPolygonCoordinates([Point(107, 243), Point(103, 234), Point(110, 234)]) == [Point(107.11, 244.98), Point(101.45, 232.73), Point(111.49, 232.66)]
    @test getPolygonStyle("poly (107,243,103,234,107,237,110,234)") == "top:240px;left:109px;width:7px;height:9px;clip-path:polygon(7.11px 13.98px, 1.45px 1.73px, 11.49px 1.66px);"

    @test getStyle("circ (541,878) 4") == "left:$(539 + TRANSLATE).0px;top:$(876 + TRANSLATE).0px;width:4px;height:4px;"
    @test getStyle("something else") == ""
    @test getClass("circ (541,878) 4", "") == "circ"
    @test getClass("rect (40,45) (388,70)", "/dbget-bin/www_bget?hsa01040") == "rect"
    @test getClass("rect (40,45) (388,70)", "/kegg-bin/show_pathway?hsa00030") == "rect rounded"

    genes = [Gene("hsa:51181"), Gene("hsa:8789"), Gene("mmu:8789"), Gene("hsa:2203")]
    @test getGenes("/dbget-bin/www_bget?hsa:2203+hsa:8789", Ref(genes)) == [genes[4], genes[2]]

    append!(genes[2].entryIds, ["P12345", "Q54321"])
    append!(genes[4].entryIds, ["Q12345", "P54321"])
    entries = [Entry("P12345", "123", "Condition", 1, ""), Entry("Q54321", "543", "Condition", 3, "")]
    @test isempty(makeTooltipText(params, "Ahsa01040", "Biosynthesis of unsaturated fatty acids - Homo sapiens (human)", Ref(entries), Ref(Vector{Gene}()), ""))
    tooltip = makeTooltipText(params, "Ahsa01040", "Biosynthesis of unsaturated fatty acids - Homo sapiens (human)", Ref(entries), Ref(genes), "")
    @test length(tooltip) == 4

    @test getFullStatus(params, Ref(entries), Ref(genes)) == "UP"
    entries = [Entry("P12345", "123", "Condition", 2, ""), Entry("Q54321", "543", "Condition", 3, "")]
    @test getFullStatus(params, Ref(entries), Ref(genes)) == "OK-UP"

    confFile = string(@__DIR__, "/../test_data/kegg-hsa01040.conf")
    body = getHtmlBody(params, confFile, Ref(entries), Ref(genes))
    @test length(body) == 422

    @test length(makeJs("")) == 27
    @test length(getHtmlEndOfFile()) == 31
    lines = getHtmlContent(params, pathway, confFile, imgFile, Ref(entries), Ref(genes))
    @test length(lines) == 92 + 422 + 31

    append!(genes, [Gene("hsa:3295"), Gene("hsa:9200"), Gene("hsa:51495")])
    append!(genes[6].entryIds, ["P12345", "Q54321"])
    append!(genes[7].entryIds, ["Q12345", "P54321"])
    htmlFile = createHtmlFile(params, pathway, confFile, imgFile, Ref(entries), Ref(genes), string(@__DIR__, "/../temp/"))
    @test isfile(htmlFile)
    @test filesize(htmlFile) > 175000
    rm(htmlFile)
end

@testset "PathwayGrabber-Common" begin
    inputFile = string(@__DIR__, "/../test_data/kegg-uniprot.xlsx")
    conditions = Vector{String}()
    for i in 1:28 push!(conditions, "My-Condition-$i") end
    json = Dict{String, Any}("inputFile" => inputFile, "sheetNumber" => 1, "headerLine" => 1, "idType" => "uniprot", "type" => Dict("value" => false, "statistics" => Dict("value" => "conditions", "col_id" => "B", "col_pvalue" => "C", "col_tukey" => "D", "col_fc" => "E", "conditions" => join(conditions, "__cn__"))), "thresholds" => Dict("pvalue" => 0.05, "tukey" => 0.05, "fc" => 1.5))
    params = getParams(json, "kegg-uniprot.xlsx")
    @test params.conditionLabels == conditions
    @test getFirstColumnNumber(params) == 2
    @test estimateNbConditions(params, 59) == length(conditions)

    @test looksLikeUniProt("P12345") == true
    @test looksLikeUniProt("INS1_MOUSE") == true
    @test looksLikeUniProt("P12345_RABIT") == true
    @test looksLikeUniProt("sp|P12345") == false

    @test isValid(NaN, 0.05) == false
    @test isValid(Missing, 0.05) == false
    @test isValid(0.1, 0.05) == false
    @test isValid(0.001, 0.05) == true

    @test getCurrentStatusId(params, 0.25, 0.972, 1.1) == KO # pvalue > threshold (0.05)
    @test getCurrentStatusId(params, 0.0025, 0.972, 1.1) == KO # tukey > threshold (0.05)
    @test getCurrentStatusId(params, 0.0025, 0.001, NaN) == OK # no fc value
    @test getCurrentStatusId(params, 0.0025, 0.001, 0.0) == OK # -1.5 < fc < 1.5
    @test getCurrentStatusId(params, 0.0025, 0.001, 2.0) == UP # fc > 1.5
    @test getCurrentStatusId(params, 0.0025, 0.001, -2.0) == DO # fc < -1.5

    @test getKey(Params(InputFile(), "", true, "", Columns(), Vector{String}(), Thresholds()), Entry("P12345", "123", "Condition", 1, "")) == "P12345 at site 123"
    @test getKey(Params(InputFile(), "", false, "", Columns(), Vector{String}(), Thresholds()), Entry("P12345", "123", "Condition", 1, "")) == "P12345"
    
    XLSX.openxlsx(params.input.path, enable_cache = false) do xf
        for row in XLSX.eachrow(xf[1])
            if(XLSX.row_number(row) == 1)
                @test getConditions(params, row) == conditions
                @test isnan(getScore(row, "J"))
            elseif(XLSX.row_number(row) == 2)
                @test isapprox(getScore(row, "C"), 0.0199; atol = 0.0001)
                @test getScore(row, "D") == 0.6672
                statusIds = getStatusIds(params, row, 28)
                @test length(statusIds) == 28
                @test count(s -> s == KO, collect(values(statusIds))) == 27
            elseif(XLSX.row_number(row) == 5)
                @test isnan(getScore(row, "J"))
            elseif(XLSX.row_number(row) == 7)
                statusIds = getStatusIds(params, row, 28)
                @test length(statusIds) == 28
                @test count(s -> s == OK, collect(values(statusIds))) == 4
                entries = getEntries(params, row, conditions)
                @test length(entries) == 28
                @test entries[2].statusId == OK
            end
        end
    end

    entriesRef, duplicatesRef = extractData(params)
    @test length(entriesRef[]) == 6 * 28
    @test length(duplicatesRef[]) == 1
    @test duplicatesRef[]["P07900"] == 1

    searchUniprotEntries(entriesRef)
    @test count(e -> e.uniprotIdentifier == "", entriesRef[]) == 0

    worthy = getWorthyEntries(params, entriesRef)[]
    @test length(worthy) == 5 * 28

    gene = Gene("hsa:201562")
    addPathways(params, Ref([gene]))
    @test length(gene.pathwaysIds) == 4

    keggs = getKeggData(params, entriesRef)[]
    @test length(keggs) == 5

    # @test getNbDaysSinceLastModification(inputFile) > 0
    @test isFileUpdadeRequired("abu01234") == true # fake file that does not exist

    tempDirectory = string(@__DIR__, "/../temp/")
    testFile = string(tempDirectory, "kegg-test.conf")
    downloadPathway("hsa01040", "", testFile)
    @test isfile(testFile)
    @test filesize(testFile) > 10000
    rm(testFile)

    infoFile = string(@__DIR__, "/../test_data/kegg-hsa01040.txt")
    pathway = getPathway(infoFile)
    @test pathway.id == "hsa01040"
    @test pathway.name == "Biosynthesis of unsaturated fatty acids - Homo sapiens (human)"
    @test length(pathway.data) == 9
    @test haskey(pathway.data, "GENE")
    @test length(pathway.data["GENE"]) == 27

    pathways = downloadUpdateGenerate(params, entriesRef, Ref(keggs), tempDirectory)[]
    @test length(pathways) == 19
    for f in readdir(tempDirectory)
        file = string(tempDirectory, "/$f")
        if(isfile(file)) rm(file) end
    end
end

@testset "PathwayGrabber-Xlsx" begin
    inputFile = string(@__DIR__, "/../test_data/kegg-uniprot.xlsx")
    conditions = Vector{String}()
    for i in 1:28 push!(conditions, "My-Condition-$i") end
    json = Dict{String, Any}("inputFile" => inputFile, "sheetNumber" => 1, "headerLine" => 1, "idType" => "uniprot", "type" => Dict("value" => false, "statistics" => Dict("value" => "conditions", "col_id" => "B", "col_pvalue" => "C", "col_tukey" => "D", "col_fc" => "E", "conditions" => join(conditions, "__cn__"))), "thresholds" => Dict("pvalue" => 0.05, "tukey" => 0.05, "fc" => 1.5))
    params = getParams(json, "kegg-uniprot.xlsx")

    @test match(r"^[0-9\.\+]+/[0-9\-]+, [A-Z][a-z]+ [0-9]{1,2}$", getKeggRelease()) !== nothing # 106.0+/05-04, May 23
    @test getStatistics(params) == "Anova p-values and multiple conditions each with a Tukey value and a Fold Change"

    duplicates = Dict{String, Int64}()
    duplicates["P12345"] = 5
    duplicates["Q12345"] = 2
    duplicates["P54321"] = 1
    duplicates["Q54321"] = 2
    @test length(getFirstSheet(params, Ref(duplicates))) == 16 + (!isempty(duplicates) ? 1 + length(duplicates) : 0)

    entry = Entry("P12345", "", "Cnd", OK, "")
    pathways = Vector{Pathway}()
    append!(pathways, [Pathway("hsa00031", "name", LittleDict()), Pathway("hsa00032", "name", LittleDict()), Pathway("hsa00033", "name", LittleDict()), Pathway("hsa00034", "name", LittleDict()), Pathway("hsa00035", "name", LittleDict())])
    genes = Vector{Gene}()
    push!(genes, Gene("hsa:51181", ["hsa00031", "hsa00034"], ["P12345", "Q54321"]))
    push!(genes, Gene("hsa:51182", ["hsa00032", "hsa00033"], ["P54321", "Q12345"]))
    push!(genes, Gene("hsa:51183", ["hsa00031", "hsa00035"], ["P12345", "Q12345"]))
    @test getPathways(entry, Ref(genes), Ref(pathways)) == [pathways[1], pathways[4], pathways[5]]

    pathway1 = Pathway("hsa00031", "name", LittleDict("ENTRY" => ["hsa01040 [Pathway]"], "COMPOUND" => ["C00154 [Palmitoyl-CoA]", "C00219 [Arachidonate]"]))
    @test getPathwayClassLevels(pathway1) == ("", "")
    pathway2 = Pathway("hsa00031", "name", LittleDict("ENTRY" => ["hsa01040 [Pathway]"], "COMPOUND" => ["C00154 [Palmitoyl-CoA]", "C00219 [Arachidonate]"], "CLASS" => ["Metabolism"]))
    @test getPathwayClassLevels(pathway2) == ("Metabolism", "")
    pathway3 = Pathway("hsa00031", "name", LittleDict("ENTRY" => ["hsa01040 [Pathway]"], "COMPOUND" => ["C00154 [Palmitoyl-CoA]", "C00219 [Arachidonate]"], "CLASS" => ["Metabolism; Lipid metabolism"]))
    @test getPathwayClassLevels(pathway3) == ("Metabolism", "Lipid metabolism")
    @test getPathwaySummary([pathway1, pathway2, pathway3]) == "hsa00031:name\nhsa00031:name:Metabolism\nhsa00031:name:Metabolism:Lipid metabolism"

    lines = getSecondSheet(params, Ref([entry]), Ref(genes), Ref([pathway1, pathway2, pathway3]))
    @test length(lines) == 2 # one header, one entry
    @test length(lines[1]) == 6

    entries = getCorrespondingEntries(pathway1, Ref(genes))
    @test entries == ["P12345", "Q12345", "Q54321"]

    lines = getThirdSheet(Ref([pathway1, pathway2, pathway3]), Ref(genes))
    @test length(lines) == 4

    tempDirectory = string(@__DIR__, "/../temp/")
    xlsxFile = writeExcelOutput(params, Ref([entry]), Ref(genes), Ref([pathway1, pathway2, pathway3]), Ref(duplicates), tempDirectory)
    @test isfile(xlsxFile)
    @test filesize(xlsxFile) > 10000
    rm(xlsxFile)
end

@testset "PathwayGrabber" begin
    inputFile = string(@__DIR__, "/../test_data/kegg-compounds.xlsx")
    conditions = Vector{String}()
    json = Dict{String, Any}("inputFile" => inputFile, "sheetNumber" => 1, "headerLine" => 1, "idType" => "kegg", "type" => Dict("value" => false, "statistics" => Dict("value" => "pvalue_fc", "col_id" => "A", "col_pvalue" => "B", "col_fc" => "C")), "thresholds" => Dict("pvalue" => 0.05, "tukey" => 0.05, "fc" => 1.5))
    outputFileXlsx = string(@__DIR__, "/../temp/kegg.xlsx")
    outputFileZip = string(@__DIR__, "/../temp/kegg.zip")
    runWithParams(json, "kegg-compounds.xlsx", outputFileXlsx, outputFileZip)
    @test isfile(outputFileXlsx)
    @test filesize(outputFileXlsx) > 10000
    rm(outputFileXlsx)
    @test isfile(outputFileZip)
    @test filesize(outputFileZip) > 5000000
    rm(outputFileZip)

    inputFile = string(@__DIR__, "/../test_data/kegg-uniprot.xlsx")
    conditions = Vector{String}()
    json = Dict{String, Any}("inputFile" => inputFile, "sheetNumber" => 1, "headerLine" => 1, "idType" => "uniprot", "type" => Dict("value" => false, "statistics" => Dict("value" => "conditions", "col_id" => "B", "col_pvalue" => "C", "col_tukey" => "D", "col_fc" => "E", "conditions" => join(conditions, "__cn__"))), "thresholds" => Dict("pvalue" => 0.05, "tukey" => 0.05, "fc" => 1.5))
    outputFileXlsx = string(@__DIR__, "/../temp/kegg.xlsx")
    outputFileZip = string(@__DIR__, "/../temp/kegg.zip")
    runWithParams(json, "kegg-uniprot.xlsx", outputFileXlsx, outputFileZip)
    @test isfile(outputFileXlsx)
    @test filesize(outputFileXlsx) > 15000
    rm(outputFileXlsx)
    @test isfile(outputFileZip)
    @test filesize(outputFileZip) > 3000000
    rm(outputFileZip)

    inputFile = string(@__DIR__, "/../test_data/kegg-uniprot-site.xlsx")
    conditions = Vector{String}()
    json = Dict{String, Any}("inputFile" => inputFile, "sheetNumber" => 1, "headerLine" => 1, "idType" => "uniprot", "type" => Dict("value" => true, "statistics" => Dict("value" => "conditions", "col_id" => "A", "col_site" => "B", "col_pvalue" => "C", "col_tukey" => "D", "col_fc" => "E", "conditions" => join(conditions, "__cn__"))), "thresholds" => Dict("pvalue" => 0.05, "tukey" => 0.05, "fc" => 1.5))
    outputFileXlsx = string(@__DIR__, "/../temp/kegg.xlsx")
    outputFileZip = string(@__DIR__, "/../temp/kegg.zip")
    runWithParams(json, "kegg-uniprot-site.xlsx", outputFileXlsx, outputFileZip)
    @test isfile(outputFileXlsx)
    @test filesize(outputFileXlsx) > 25000
    rm(outputFileXlsx)
    @test isfile(outputFileZip)
    @test filesize(outputFileZip) > 2000000
    rm(outputFileZip)
end
=#

end