using Logging, LoggingExtras, Gzip_jll, FilesystemDatastructures

# TODO improve console log format eventually
# TODO format are not the same on both loggers (maybe better that way)

# Set log level
LOG_LEVEL = Logging.Info
Logging.LogLevel(LOG_LEVEL)

# Directory for our log files
LOGDIR = joinpath(@__DIR__, "/../logs")
mkpath(LOGDIR)

# Filename pattern
pattern = raw"\P\a\t\h\w\a\y\G\r\a\b\b\e\r-yyyy-mm-dd.\l\o\g"

# File cache that keeps 30 files (only delete *.log.gz files)
fc = NFileCache(LOGDIR, 30, DiscardLRU(); predicate = x -> endswith(x, r"\.log\.gz"))

# Callback function for compression and adding to cache
function loggerCallback(file)
    # Compress the file
    Gzip_jll.gzip() do gzip run(`$(gzip) $(file)`) end
    # Add the compressed file to the cache (gzip adds the .gz extension)
    FilesystemDatastructures.add!(fc, file * ".gz")
end

# Create the logger
dtLogger = DatetimeRotatingFileLogger(LOGDIR, pattern; rotation_callback = loggerCallback) do io, args
    # the logs are filtered here but there's certainly a better way to do it!!!
    if(args.level >= LOG_LEVEL) println(io, "[", args.level, "] ", Dates.format(now(), "YYYY-mm-dd HH:MM:SS"), " | ", args._module, " | ", args.message) end
end

# Install the logger globally
logger = TeeLogger(global_logger(), dtLogger)
global_logger(logger)
