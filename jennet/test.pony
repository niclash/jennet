use "collections"
use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(_TestMuxTree)

// TODO UTF8 support
class iso _TestMuxTree is UnitTest
  fun name(): String => "Test _MuxTree"

  fun apply(h: TestHelper) ? =>
    let routes =
      recover val
        [ as (String, U8):
          ("/", 0)
          ("/foo", 1)
          // ("/:foo", 2)
          // ("/foo/bar/", 3)
          // ("/baz/bar", 4)
          // ("/:foo/baz", 5)
          // ("/foo/bar/*baz", 6)
          // ("/fi", 7)
          // ("/fizz", 8)
        ]
      end
    let mux = _MuxTree[U8]
    for (route, n) in routes.values() do
      mux.add_route(route.clone(), n)?
    end

    let tests =
      [ as (String, U8, Array[(String, String)]):
        ("/", 0, [])
        ("/foo", 1, [])
        // ("/stuff", 2, [("foo", "stuff")])
        // ("/a", 2, [("foo", "a")])
        // ("/1", 2, [("foo", "1")])
        // ("/foo/bar/", 3, [])
        // ("/foo/bar", -1, [])
        // ("/baz/bar", 4, [])
        // ("/stuff/baz", 5, [("foo", "stuff")])
        // ("/stuff/baz/", -1, [])
        // ("/foo/bar/stuff/and/things", 6, [("baz", "stuff/and/things")])
        // ("/foo/bar/a", 6, [("baz", "a")])
        // ("/foo/bar//", 6, [("baz", "/")]) // TODO is this ok?
        // ("/fi", 7, [])
        // ("/fizz", 8, [])
      ]
    for (path, n, params) in tests.values() do
      if n == -1 then
        h.assert_error({()? => mux.get_route(path.clone())? })
      else
        (let n', let params') = mux.get_route(path.clone())?
        h.assert_eq[U8](n, n')
        h.assert_eq[USize](params.size(), params'.size())
        for (param, value) in params.values() do
          h.assert_eq[String](params'(param)?, value)
        end
      end
    end
