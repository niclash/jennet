use "collections"

use "debug" // TODO remove

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
          _MuxTree[_JennetHandler](path where handler' = handler)
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
    _methods(method)?(path', recover Map[String, String] end)?

// TODO UTF-8 support
class _MuxTree[A: Any #share]
  """
  Radix tree with support for path variables and wildcards
  """
  var _root: _MuxTree[A]
  var _path: Array[_PathTok]
  var _trailing_slash: Bool

  new create(path: String, handler: A) =>
    _path = _lex_path(path)

  fun ref add_route(path: String, handler: A) ? =>
    error // TODO

  // TODO add parameter for vars to allow reuse
  fun get_route(path: String): (A, Map[String, String] iso^) ? =>
    _root.get_route(path, recover Map[String, String] end)?

  fun _lex_path(path: String): Array[_PathTok] =>
    let toks = Array[_PathTok]
    // reuse path memory for tokens
    var start: USize = 0
    var len: USize = 0

    var param = false
    var wild = false

    let push_tok =
      {(start: USize, len: USize, param: Bool, wild: Bool) =>
        let name = path.trim(start, start + len)
        toks.push(
          if param then ParamTok(name)
          elseif wild then WildTok(name)
          else name
          end) 
      }

    for b in path.values() do
      match b
      | '/' => // end of token
        if buff.size() == 0 then continue // ignore leading & duplicate slashes
        else
          push_tok(start, len, param, wild)
          (start, len, param, wild) = (0, 0, false, false)
        end
      end
    end
    if buff.size() > 0 then push_tok(start, len, param, wild) end
    toks

type _PathTok is (String | ParamTok | WildTok)

class val ParamTok
  let name: String
  
  new create(name': String) =>
    name = name'

class val WildTok
  let name: String

  new create(name': String) =>
    name = name'
