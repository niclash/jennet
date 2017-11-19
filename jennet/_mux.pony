use "collections"
use "debug" // TODO logger?

// TODO cleanup extra debugging

type _RouteData is (String, String, _JennetHandler)
  """(method, path, handler)"""

class val _RouterMux
  embed _methods: Map[String, _MuxTree[_JennetHandler]]

  new iso create(routes: Array[_RouteData] val) ? =>
    _methods = Map[String, _MuxTree[_JennetHandler]]
    for route_data in routes.values() do
      (let method, let path, let handler) = route_data
      if _methods.contains(method) then
        _methods(method)?.add_route(_LexPath(path), handler)?
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

  fun is_var_node(): Bool =>
    try
      match _path(0)?
      | let _: String => false
      else true
      end
    else false
    end

  fun ref add_route(path: Array[_PathTok], handler: A) ? =>
    Debug.out("add route: " + _log_path(path) + " at " + _log_path())
    for (i, tok) in _path.pairs() do
      match (tok, path(0)?)
      | (let s1: String, let s2: String) =>
        if s1 != s2.trim(0, s1.size()) then
          if s1(0)? != s2(0)? then // fork at root
            _fork(i, path, handler)?
            return
          end
          // split static
          Debug.out("split static")
          // TODO can this just use _fork with some tweaking?
          var cut: USize = 1
          while s1(cut)? == s2(cut)? do cut = cut + 1 end
          let p1 = _path.slice(i) .> update(0, s1.trim(cut))?
          let p2 = path .> update(0, s2.trim(cut))?
          let children' = Array[_MuxTree[A]]
            .> push(_create(p1, _children, _handler))
            .> push(_create(p2, [], handler))
          _path = _path.slice(0, i + 1)
          _path(i)? = s1.trim(0, cut)
          _children = children'
          _handler = None
          _reorder()?
          return
        elseif s1 != s2 then
          // partial static
          Debug.out("partial static")
          var cut: USize = 1
          while(cut < s1.size()) and (s1(cut)? == s2(cut)?) do 
            cut = cut + 1
          end
          path(0)? = s2.trim(cut)
          continue
        end
      | (let s1: String, _) =>
        _fork(i, path, handler)?
        return
      | (_, let s2: String) =>
        _fork(i, path, handler)?
        return
      end
      path.shift()?
    end
    if path.size() == 0 then
      Debug.out("Error: path already exists: " + _log_path())
      error
    end
    Debug.out("remaining: " + _log_path(path))
    for child in _children.values() do
      match (child._path(0)?, path(0)?)
      | (let s1: String, let s2: String) =>
        if s1(0)? == s2(0)? then
          Debug.out("add to static child: " + s1)
          return child.add_route(path, handler)?
        end
      | (let p1: _ParamTok, let p2: _ParamTok) =>
        if p1.name == p2.name then
          return child.add_route(path, handler)?
        end
      end
    end
    Debug.out("new child")
    _children.push(_create(path, [], handler))
    _reorder()?

  fun ref _fork(i: USize, path: Array[_PathTok], handler: A) ? =>
    let children' = Array[_MuxTree[A]]
      .> push(_create(_path.slice(i), _children, _handler))
      .> push(_create(path, [], handler))
    _path = _path.slice(0, i)
    _children = children'
    _handler = None
    _reorder()?

  fun ref _reorder() ? =>
    // TODO put param/wild children last, error if there are more than 1
    if _children.size() < 2 then return end
    var var_tok_i: USize = -1
    for (i, child) in _children.pairs() do
      if child.is_var_node() then
        if var_tok_i == -1 then var_tok_i = i
        else
          Debug.out("Error: ambiguous path added to " + _log_path())
          error
        end
      end
    end
    if var_tok_i != -1 then
      _children.swap_elements(var_tok_i, _children.size() - 1)?
    end

  // TODO make sure given Map is reused in router
  // TODO no partial for better performance on unmatched routes?
  fun get_route(path: String, vars: _Vars): (A, _Vars^) ? =>
    Debug.out("get route: " + path + " at " + _log_path())
    var i: USize = 0
    for tok in _path.values() do
      while path(i)? == '/' do i = i + 1 end // ignore extra slashes
      match tok
      | let s: String =>
        let chunk = path.trim(i, i + s.size())
        if s != chunk then error end
        i = i + s.size()
      | let p: _ParamTok =>
        Debug.out("param " + path.trim(i))
        let start = i
        while (i < path.size()) and (path(i)? != '/') do i = i + 1 end
        vars(p.name) = path.trim(start, i)
      | let w: _WildTok =>
        vars(w.name) = path.trim(i)
        return (_handler as A, consume vars)
      end
    end
    while (i < path.size()) and (path(i)? == '/') do i = i + 1 end
    if i == path.size() then // edge reached
      Debug.out("edge")
      return (_handler as A, consume vars)
    end
    // continue to children
    let remaining = path.trim(i)
    Debug.out("remaining: " + remaining)

    for child in _children.values() do
      match child._path(0)?
      | let s: String =>
        Debug.out("static child " + s)
        if s == remaining.trim(0, s.size()) then
          return child.get_route(remaining, consume vars)?
        end
      // give to param or wild (must be last in _children)
      | let p: _ParamTok =>
        return child.get_route(remaining, consume vars)?
      | let w: _WildTok =>
        return child.get_route(remaining, consume vars)?
      end 
    end
    Debug.out("not found")
    error // not found

  fun _try_wild(path: String, vars: _Vars): (A, _Vars^) ? =>
    if (_children.size() > 0) then
      try
        let last_child = _children(_children.size() - 1)?
        match last_child._path(0)?
        | let w: _WildTok => return last_child.get_route(path, consume vars)?
        end
      end
    end
    error

  fun _log_path(path: (Array[_PathTok] box | None) = None): String iso^ =>
    let path' =
      match consume path
      | let p: Array[_PathTok] box => p
      | None => _path
      end
    let str = recover String end
    for tok in path'.values() do
      match tok
      | let s: String => str.append(s)
      | let p: _ParamTok => str .> append(":") .> append(p.name)
      | let w: _WildTok => str .> append("*") .> append(w.name)
      end
      str.append("/")
    end
    // TODO trailing slash?
    // if (path'.size() > 0) and (_handler is None) then
    if path'.size() > 0 then
      try str.pop()? end
    end
    str

  fun _debug_tree(indent: USize = 0): String iso^ =>
    // TODO make pretty like tree command
    let str = recover String end
    if indent == 0 then
      str.append("/")
    else
      for i in Range(0, indent + str.size()) do str.append(" ") end
    end
    str.append(_log_path())
    let indent' = str.size()
    for child in _children.values() do
      str .> append("\n") .> append(child._debug_tree(indent'))
    end
    str

primitive _LexPath
  fun apply(path: String): Array[_PathTok] =>
    let toks = Array[_PathTok]
    // reuse path memory for tokens
    var start: USize = 0
    var param = false
    var wild = false

    let push_tok =
      {ref(start: USize, i: USize, param: Bool, wild: Bool)(toks) =>
        let name = path.trim(start, i)
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
        if (i - start) > 0 then // ignore slashes
          push_tok(start, i, param, wild)
          (param, wild) = (false, false)
        end
        start = i + 1
      | ':' =>
        param = true
        start = start + 1
      | '*' =>
        wild = true
        start = start + 1
      end
      i = i + 1
    end
    if (i - start) > 0 then push_tok(start, i, param, wild) end
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
