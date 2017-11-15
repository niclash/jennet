use "collections"

class val _Dummy // TODO route object

type _RouteData is (String, String, _Dummy)
  """(method, path, TODO)""" // TODO

class val _RouterMux
  embed _methods: Map[String, _MuxTree[_Dummy]]

  new iso create(routes: Array[_RouteData]) ? =>
    _methods = Map[String, _MuxTree[_Dummy]]
    for route_data in routes.values() do
      // TODO refactor 'dummy'
      (let method, let path, let dummy) = (route_data._1
      if _methods.contains(method) then
        _methods(method)(path) = dummy
      else
        _methods(method) = _MuxTree[_Dummy](path, dummy)
      end
    end

  fun apply(method: String, path: String):
    (_Dummy, Map[String, String] iso^) ?
  =>
    """
    Sanitize input with leading slash and return matched _Dummy and path
    variables collected. An error will be raised if the path is not matched.
    """
    error // TODO

class _MuxTree[A: Any val]
  """
  Radix tree with support for path variables and wildcards
  """
