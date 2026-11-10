-- cangjie_fluency.lua
--
-- A librime-lua *processor* that makes a fluency_editor based Cangjie schema
-- behave more like Microsoft New Cangjie (新倉頡) sentence-style typing.
--
-- STATUS: tested only on Linux/aarch64 with Debian librime 1.10.0 +
-- librime-plugin-lua 1.10.0+git20230917 (see docs/item4-analysis.md, section
-- "Test log").  NOT yet tested on Windows / Weasel 0.17.4 (librime 1.13.1 with
-- a newer librime-lua build).  API names used (all present in the 2023 build's
-- binary strings, and in the upstream wiki):
--   KeyEvent: keycode, shift() ctrl() alt() super() release()
--   Engine:   context, schema.config, process_key(key), commit_text(str)
--   Context:  input, composition, is_composing(), commit(), push_input(str),
--             get_option(name)
--   Composition: empty(), back();  Segment: has_tag(tag)
--   Config:   get_string(path), get_bool(path)
-- Unverified on Weasel's build: exact behaviour of engine:process_key()
-- re-entrancy (we guard it with env.replaying) -- see "Assumptions" at the end.
--
-- WHAT IT DOES (every behaviour has a switch, see `cangjie_fluency:` in
-- schema_snippet.yaml; defaults shown here):
--
--  space   (cangjie_fluency/space = "buffer")
--      buffer empty      -> not handled; space goes to the application.
--      buffer not empty  -> a space is APPENDED to the buffer as a syllable
--                           delimiter (the schema's speller/delimiter must
--                           contain " ", as in quick5_fluency).  Nothing is
--                           committed.  A second consecutive space is passed
--                           on to the editor (-> fluency_editor "confirm"),
--                           or swallowed with double_space = "ignore".
--
--  uppercase A-Z while composing (cangjie_fluency/uppercase = "commit")
--      "commit"  : commit the buffer, then the letter; following lowercase
--                  letters start a NEW Chinese buffer.  Works with any schema.
--      "literal" : append the letter to the buffer as a literal and keep
--                  composing.  Needs abc_segmentor-style segmentation and NO
--                  `uppercase` recognizer pattern, otherwise the tail turns
--                  into raw ASCII (this is the bug quick5_fluency#2 item 5).
--      "default" : do nothing (stock behaviour).
--
--  other ASCII symbols while composing (cangjie_fluency/symbols = "default")
--      "default" : stock punctuator decides (`{commit: x}` entries commit the
--                  buffer then the symbol; plain `x: y` entries append).
--      "append"  : MS-like: every key in cangjie_fluency/symbol_chars is
--                  appended to the buffer, nothing is committed.
--
--  empty buffer + uppercase / digit / symbol (cangjie_fluency/empty_direct = true)
--      The key is run through the normal processor chain once and whatever
--      that left in the buffer (e.g. "（" from "(" , "1", "A") is committed at
--      once, instead of waiting in the buffer for Enter.  This gives MS-like
--      "no content in buffer -> goes straight to the application", while
--      still letting the punctuator pick the output (， vs ,) and the
--      full_shape formatter apply.

local kRejected, kAccepted, kNoop = 0, 1, 2

local P = {}

local function cfg_string(config, ns, key, default)
  local v = config:get_string(ns .. "/" .. key)
  if v == nil or v == "" then return default end
  return v
end

local function cfg_bool(config, ns, key, default)
  local v = config:get_bool(ns .. "/" .. key)
  if v == nil then return default end
  return v
end

function P.init(env)
  local config = env.engine.schema.config
  local ns = "cangjie_fluency"
  env.cfg = {
    space        = cfg_string(config, ns, "space", "buffer"),          -- buffer | default
    double_space = cfg_string(config, ns, "double_space", "default"),  -- default | ignore
    uppercase    = cfg_string(config, ns, "uppercase", "commit"),      -- commit | literal | default
    symbols      = cfg_string(config, ns, "symbols", "default"),       -- default | append
    -- keys that "append" mode takes.  Excluded on purpose: ` (reverse lookup
    -- prefix), ' and ; (speller delimiters), digits (candidate selection),
    -- - = , . (paging in stock key_binder) -- add them if your schema frees them.
    symbol_chars = cfg_string(config, ns, "symbol_chars",
                              "!?()[]{}<>/\\|@#$%^&*_+~:\""),
    empty_direct = cfg_bool(config, ns, "empty_direct", true),
  }
  env.replaying = false
end

local function is_upper(ch) return ch >= 0x41 and ch <= 0x5a end
local function is_digit(ch) return ch >= 0x30 and ch <= 0x39 end
local function is_lower(ch) return ch >= 0x61 and ch <= 0x7a end

-- Is the tail of the buffer something we must not interfere with
-- (reverse lookup "`...", where space/uppercase keep their stock meaning)?
local function in_reverse_lookup(ctx)
  if ctx.input:sub(1, 1) == "`" then return true end
  local comp = ctx.composition
  if comp:empty() then return false end
  local seg = comp:back()
  return seg ~= nil and seg:has_tag("reverse_lookup")
end

-- Replay `key` through the whole processor chain (we are called FIRST, so the
-- chain contains us again: env.replaying makes that second call a no-op), then
-- commit whatever the key left in the buffer.
local function replay_and_commit(key, env)
  local ctx = env.engine.context
  env.replaying = true
  local ok, handled = pcall(function() return env.engine:process_key(key) end)
  env.replaying = false
  if not ok then return kNoop end                 -- be safe: let the chain run normally
  if ctx:is_composing() then ctx:commit() end
  if handled then return kAccepted end
  return kRejected                                -- nobody wanted it: application gets it
end

function P.func(key, env)
  if env.replaying then return kNoop end
  if key:release() or key:ctrl() or key:alt() or key:super() then return kNoop end
  local ctx = env.engine.context
  if ctx:get_option("ascii_mode") then return kNoop end
  local ch = key.keycode
  if ch < 0x20 or ch > 0x7e then return kNoop end

  local cfg = env.cfg
  local composing = ctx:is_composing()

  ------------------------------------------------------------------ empty buffer
  if not composing then
    if ch == 0x20 or is_lower(ch) then return kNoop end   -- stock: space -> app, letters -> speller
    if ch == 0x60 then return kNoop end                   -- ` starts reverse lookup
    if cfg.empty_direct then return replay_and_commit(key, env) end
    return kNoop
  end

  ------------------------------------------------------------------ buffer has content
  if in_reverse_lookup(ctx) then return kNoop end

  if ch == 0x20 then
    if key:shift() then return kNoop end                  -- Shift+space: key_binder (full_shape toggle)
    if cfg.space ~= "buffer" then return kNoop end
    if ctx.input:sub(-1) == " " then
      if cfg.double_space == "ignore" then return kAccepted end
      return kNoop                                        -- stock: editor confirms / commits
    end
    ctx:push_input(" ")
    return kAccepted
  end

  if is_upper(ch) then
    if cfg.uppercase == "commit" then
      ctx:commit()
      env.engine:commit_text(string.char(ch))
      return kAccepted
    elseif cfg.uppercase == "literal" then
      ctx:push_input(string.char(ch))
      return kAccepted
    end
    return kNoop
  end

  if cfg.symbols == "append" and not is_lower(ch) and not is_digit(ch) then
    local c = string.char(ch)
    if cfg.symbol_chars:find(c, 1, true) then
      ctx:push_input(c)
      return kAccepted
    end
  end

  return kNoop
end

function P.fini(env)
  env.cfg = nil
end

-- Assumptions that could not be verified on Weasel's librime-lua build:
--  1. engine:process_key(key) is re-entrant from inside a lua_processor and
--     returns a boolean (verified on the Debian 2023 build only).
--  2. key.keycode is a number and key:shift()/ctrl()/... are methods
--     (matches the upstream wiki; verified on the Debian build).
--  3. Weasel delivers Shift+A as keycode 0x41 with kShiftMask (tested both
--     with and without the mask on Linux; Weasel behaviour itself unverified).
--  4. A commit followed by kAccepted (uppercase "commit" mode) is delivered to
--     the application in order (commit text first, then letter) -- same
--     pattern as Editor::DirectCommit in editor.cc, but Weasel TSF ordering is
--     unverified.

return P
