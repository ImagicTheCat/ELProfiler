package = "ELProfiler"
version = "scm-1"
source = {
  url = "git://github.com/ImagicTheCat/ELProfiler",
}

description = {
  summary = "Embeddable Lua Profiler is a pure Lua statistical/sampling profiler.",
  detailed = [[
  ]],
  homepage = "https://github.com/ImagicTheCat/ELProfiler",
  license = "MIT"
}

dependencies = {
  "lua >= 5.1, < 5.5"
}

build = {
  type = "builtin",
  modules = {
    ELProfiler = "src/ELProfiler.lua"
  }
}
