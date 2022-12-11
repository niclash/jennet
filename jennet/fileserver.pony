use "files"
use "http_server"
use "valbytes"

primitive _FileReader
  fun read(filename:FilePath): ByteArrays? =>
    var bs = ByteArrays
    with file = OpenFile(filename) as File do
      while true do
        let chunk:Array[U8] iso = file.read(2048)
        if chunk.size() == 0 then break end
        bs = bs + consume chunk
      end
    end
    bs

class _FileServer is RequestHandler
  let _filepath: FilePath

  new val create(filepath: FilePath) =>
    _filepath = filepath

  fun val apply(ctx: Context): Context iso^ =>
    try
      var bs = _FileReader.read(_filepath)?
      ctx.respond(StatusResponse(StatusOK), bs)
    else
      ctx.respond(StatusResponse(StatusNotFound))
    end
    consume ctx

class _DirServer is RequestHandler
  let _dir: FilePath

  new val create(dir: FilePath) =>
    _dir = dir

  fun val apply(ctx: Context): Context iso^ =>
    try
      let filepath = _dir.join(ctx.param("filepath"))?
      var bs = _FileReader.read(filepath)?
      ctx.respond(StatusResponse(StatusOK), bs)
    else
      ctx.respond(StatusResponse(StatusNotFound))
    end
    consume ctx
