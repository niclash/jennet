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

type _Vars is Map[String, String] iso

// TODO UTF-8 support
// TODO trailing slash?
class _MuxTree[A: Any #share]
  """
  Radix tree with support for path variables and wildcards
  """
  var _path: Array[_PathTok]
  var _children: Array[_MuxTree[A]]
  var _handler: (A | None)

  new create(path: String, handler: A) =>
    _path = _LexPath(path)
    _children = Array[_MuxTree[A]]
    _handler = handler
    // _trailing_slash = try path(path.size()-1)? == '/' else false end

  new _create(
    path: Array[_PathTok],
    children: Array[_MuxTree[A]],
    handler: (A | None))
  =>
    _path = path
    _children = children
    _handler = handler

  fun ref add_route(path: String, handler: A) ? =>
    error // TODO

  // TODO make sure given Map is reused in router
  // TODO no partial for better performance on unmatched routes?
  fun get_route(path: String, vars: _Vars): (A, _Vars^) ? =>
    var i: USize = 0
    for tok in _path.values() do
      while path(i)? == '/' do i = i + 1 end // ignore extra slashes
      let start: USize = i
      while (i < path.size()) and (path(i)? != '/') do i = i + 1 end
      let chunk = path.trim(start, i)
      Debug.out(chunk)
      match tok
      | let s: String => if s != chunk then error end
      | let p: _ParamTok => vars(p.name) = chunk
      | let w: _WildTok => vars(w.name) = chunk
      end
    end
    while (i < path.size()) and (path(i)? == '/') do i = i + 1 end
    // edge reached
    if i == path.size() then return (_handler as A, consume vars) end
    // TODO continue to children
    let remaining = path.trim(i)
    for child in _children.values() do
      match child._path(0)?
      | let s: String =>
        if s(0)? == remaining(0)? then
          return child.get_route(remaining, consume vars)?
        end
      else // give to param or wild (must be last in _children)
        return child.get_route(remaining, consume vars)?
      end 
    end
    error // not found

primitive _LexPath
  fun apply(path: String): Array[_PathTok] =>
    let toks = Array[_PathTok]
    // reuse path memory for tokens
    var start: USize = 0
    var len: USize = 0 // TODO necessary with i counter?

    var param = false
    var wild = false

    let push_tok =
      {ref(start: USize, len: USize, param: Bool, wild: Bool)(toks) =>
        let name = path.trim(start, start + len)
        toks.push(
          if param then _ParamTok(name)
          elseif wild then _WildTok(name)
          else name
          end)
      }

    var i: USize = 0
    for b in path.values() do
      match b
      | '/' => // end of token
        if len > 0 then // ignore slashes
          push_tok(start, len, param, wild)
          (len, param, wild) = (0, false, false)
        end
        start = i + 1
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
