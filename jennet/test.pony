use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    Ponytest(env, this)

  fun tag tests(test: Ponytest) =>
    test()

class iso _TestMuxTree
  let _
