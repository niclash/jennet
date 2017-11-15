use "net/http"

interface Middleware
  fun ref before(c: Context, req: Payload val): Context^ =>
    consume c
  
  fun ref after(c: Context): Context^ =>
    consume c

interface ResponseHandler
  fun ref apply(c: Context, req: Payload val): Context^

// Should each path have a single _HandlerGroup actor?
actor _JennetHandler
  embed _middlewares: Array[Middleware]
  let _handler: ResponseHandler

  new create(handler: ResponseHandler iso) =>
    _middlewares = Array[Middleware]
    _handler = consume handler

  be attach_middleware(middleware: Middleware iso) =>
    _middlewares.push(consume middleware)
