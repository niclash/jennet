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
    let routes
    let mux = _MuxTree[U8]
