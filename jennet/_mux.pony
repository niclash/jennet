use "collections"

type _RouteData is (String, String, _JennetHandler)
  """(method, path, handler)"""

class val _RouterMux
  embed _methods: Map[String, _MuxTree[_JennetHandler]]

  new iso create(routes: Array[_RouteData] val) ? =>
    _methods = Map[String, _MuxTree[_JennetHandler]]
    for route_data in routes.values() do
      (let method, let path, let handler) = route_data
      if _methods.contains(method) then
        _methods(method)?.add_path(path.clone(), handler)?
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

class _MuxTree[A: Any #share]
  """
  Radix tree with support for path variables and wildcards
  """
  let prefix: String
  let _params: Map[USize, String]
  let _children: Array[_MuxTree[A]]
  var _handler: (A | None)

  new create(
    prefix': String,
    params': Map[USize, String] = Map[USize, String],
    children': Array[_MuxTree[A]] = Array[_MuxTree[A]],
    handler': (A | None) = None)
  =>
    _params = params'
    _children = children'
    _handler = handler'
    let pfx = recover (consume prefix').clone() end
    if params'.size() == 0 then
      for i in Range(0, pfx.size()) do
        try
          // param
          if pfx(i)? == ':' then
            let offset =
              try pfx.find("/", i.isize())?
              else pfx.size().isize()
              end
            _params(i) = pfx.substring(i.isize() + 1, offset)
            pfx.delete(i.isize() + 1, offset.usize())
          // wild
          elseif pfx(i)? == '*' then
            _params(i) = pfx.substring(i.isize() + 1)
            pfx.delete(i.isize() + 1, pfx.size())
          end
        end
      end
    end
    prefix = consume pfx

  fun ref add_path(path: String iso, handler: A): _MuxTree[A] ? =>
    if path.size() < prefix.size() then
      let t = create(consume path, _params where handler' = handler)
      t.add_child(this)
      return t
    end

    // TODO iterate over bytes and match
    for i in Range(0, prefix.size()) do
      if prefix(i)? == ':' then
        let offset =
          try path.find("/", i.isize())?
          else path.size().isize()
          end
        let value = path.substring(i.isize(), offset)
        if value == "" then error end
        path.delete(i.isize(), offset.usize())
      elseif prefix(i)? == '*' then
        path.delete(i.isize(), path.size())
      elseif prefix(i)? != path(i)? then
        // branch in prefix
        let ps1 = Map[USize, String]
        let ps2 = Map[USize, String]
        for (k, v) in _params.pairs() do
          (if k < i then ps1 else ps2 end).update(k, v)
        end
        @printf[None]("yup!!!!\n".cstring())
        // branch
        let t = create(prefix.substring(0, i.isize()), ps1)
        let b1 = create(prefix.substring(i.isize()), ps2, _children, _handler)
        let b2 = create(path.substring(i.isize()) where handler' = handler)
        t .> add_child(b1) .> add_child(b2)
        return t // TODO Don't return, modify in place!!!
      end
    end

    let remaining = path.substring(prefix.size().isize())
    // create edge
    if remaining == "" then
      if _handler is None then
        _handler = handler
        return this
      else
        error
      end
    end
    // pass on to child
    for child in _children.values() do
      if child.prefix(0)? == remaining(0)? then
        return child.add_path(consume remaining, handler)?
      end
    end
    // add child and reorder
    let child = create(consume remaining where handler' = handler)
    _children.push(child)
    reorder()?
    this

  // TODO unnecessary method
  fun ref add_child(child: _MuxTree[A]) =>
    _children.push(child)

  fun ref reorder() ? =>
    // check if there are more than one param children
    var ps: USize = 0
    for child in _children.values() do
      if child.prefix(0)? == ':' then ps = ps + 1 end
    end
    if ps > 1 then error end
    if ps == 0 then return end
    // give param child last priority
    for (i, c) in _children.pairs() do
      if c.prefix(0)? == ':' then
        _children.delete(i)?
        _children.push(c)
        break
      end
    end

  fun apply(path: String, params: Map[String, String] iso):
    (A, Map[String, String] iso^) ?
  =>
    var path' = path
    for i in Range[ISize](0, prefix.size().isize()) do
      if prefix(i.usize())? == ':' then
        // store params
        let ns =
          try path'.find("/", i.isize())?
          else path'.size().isize()
          end
        let value = path'.substring(i, ns)
        if value == "" then error end
        params(_params(i.usize())?) = consume value
        path' = path'.cut(i.isize(), ns)
      elseif prefix(i.usize())? == '*' then
        params(_params(i.usize())?) = path'.substring(i)
        path' = path'.cut(i.isize(), path'.size().isize())
      elseif prefix(i.usize())? != path'(i.usize())? then
        // not found
        error
      end
    end

    let remaining = path'.substring(prefix.size().isize())
    // check for edge
    if remaining == "" then
      return (_handler as A, consume params)
    end
    // pass on to child
    for c in _children.values() do
      match c.prefix(0)?
      | '*' => return c(consume remaining, consume params)?
      | ':' => return c(consume remaining, consume params)?
      | remaining(0)? => return c(consume remaining, consume params)?
      end
    end
    // not found
    error
