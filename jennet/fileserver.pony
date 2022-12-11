use "files"
use "http_server"
use "valbytes"

class _FileServer is RequestHandler
  let _filepath: FilePath

  new val create(filepath: FilePath) =>
    _filepath = filepath

  fun val apply(ctx: Context): Context iso^ =>
    try
      var bs = ByteArrays
      with file = OpenFile(_filepath) as File do
        while true do
          let chunk:Array[U8] iso = file.read(2048)
          if chunk.size() == 0 then break end
          bs = bs + consume chunk
        end
      end
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
    let filepath = ctx.param("filepath")
    try
      var bs = ByteArrays
      with file = OpenFile(_dir.join(filepath)?) as File do
        for line in file.lines() do
          bs = bs + consume line + "\n"
        end
      end
      ctx.respond(StatusResponse(StatusOK), bs)
    else
      ctx.respond(StatusResponse(StatusNotFound))
    end
    consume ctx
