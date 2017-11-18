use "collections"
use "debug" // TODO logger?

type _RouteData is (String, String, _JennetHandler)
  """(method, path, handler)"""

class val _RouterMux
  embed _methods: Map[String, _MuxTree[_JennetHandler]]

  new iso create(routes: Array[_RouteData] val) ? =>
    _methods = Map[String, _MuxTree[_JennetHandler]]
    for route_data in routes.values() do
      (let method, let path, let handler) = route_data
      if _methods.contains(method) then
        _methods(method)?.add_route(path.clone(), handler)?
      else
        _methods(method) =
          _MuxTree[_JennetHandler](path where handler = handler)
      end
    end

  fun apply(method: String, path: String):
    (_JennetHandler, Map[String, String] iso^) ?
  =>
    """
    Sanitize input with leading slash and return matched _JennetHandler and
    path variables collected. An error will be raised if the path is not
    matched.
    """
    let path' =
      if path(0)? != '/' then recover path.clone() .> unshift('/') end
      else path
      end
    _methods(method)?.get_route(path', recover Map[String, String] end)?

type Vars is Map[String, String] iso

// TODO UTF-8 support
class _MuxTree[A: Any #share]
  """
  Radix tree with support for path variables and wildcards
  """
  var _path: Array[_PathTok]
  var _trailing_slash: Bool

  new create(path: String, handler: A) =>
    _path = _LexPath(path)
    _trailing_slash = false // TODO
    // _trailing_slash = try path(path.size()-1)? == '/' else false end

  fun ref add_route(path: String, handler: A) ? =>
    error // TODO

  // TODO reuse given Map
  fun get_route(path: String, vars: Vars): (A, Vars^) ? =>
    error // TODO

primitive _LexPath
  fun apply(path: String): Array[_PathTok] =>
    let toks = Array[_PathTok]
    // reuse path memory for tokens
    var start: USize = 0
    var len: USize = 0

    var param = false
    var wild = false

    let push_tok =
      {ref(start: USize, len: USize, param: Bool, wild: Bool) =>
        let name = path.trim(start, start + len)
        Debug.out(name)
        toks.push(
          if param then _ParamTok(name)
          elseif wild then _WildTok(name)
          else name
          end) 
      }

    Debug.out("")

    var i: USize = 0
    for b in path.values() do
      Debug.out(String.>push(b))
      match b
      | '/' => // end of token
        start = i + 1
        if len == 0 then None // ignore leading & duplicate slashes
        else
          push_tok(start, len, param, wild)
          Debug.out("reset")
          (len, param, wild) = (0, false, false)
        end
      | ':' =>
        if len > 0 then Debug.out("len > 0 on ':'") end
        param = true
        start = start + 1
      | '*' =>
        if len > 0 then Debug.out("len > 0 on '*'") end
        wild = true
        start = start + 1
      else
        len = len + 1
      end
      i = i + 1
    end
    if len > 0 then push_tok(start, len, param, wild) end
    toks

type _PathTok is (String | _ParamTok | _WildTok)

class val _ParamTok
  let name: String
  
  new val create(name': String) =>
    name = name'

class val _WildTok
  let name: String

  new val create(name': String) =>
    name = name'
