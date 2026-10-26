-- slides2qmd.lua -- pandoc filter used by tools/slides2qmd.py.
-- Turns a slides .docx (read as docx+styles, after the pre-pass in
-- slides2qmd.py) into draft page text laid out for the web.

local NBSP = "\u{00A0}"
local CODE = { ["Output 12.5 point"] = "stata", ["R code"] = "r", ["do-file 12 pt"] = "do" }
local DROP = { ["toc 1"] = true, ["toc 2"] = true, ["toc 3"] = true, ["TOC Heading"] = true }
local NOTE = { ["TB Note First"] = true, ["TB Note"] = true }

local keep_r = false
local last_title = ""

local function style_of(el)
  return el.t == "Div" and el.attributes["custom-style"] or nil
end

local function norm(s)
  return (s:lower():gsub("%W", ""))
end

-- text of code-styled paragraphs, keeping spacing and line breaks
local function text_of(blocks)
  local out = {}
  local function inl(list)
    for _, x in ipairs(list) do
      if x.t == "Str" then out[#out + 1] = x.text
      elseif x.t == "Space" then out[#out + 1] = " "
      elseif x.t == "SoftBreak" or x.t == "LineBreak" then out[#out + 1] = "\n"
      elseif x.t == "Code" or x.t == "Math" then out[#out + 1] = x.text
      elseif x.content then inl(x.content)
      end
    end
  end
  for _, b in ipairs(blocks) do
    if b.t == "Para" or b.t == "Plain" then inl(b.content) end
  end
  return (table.concat(out):gsub(NBSP, " "):gsub("%s+$", ""))
end

local function trim(lines)
  local a, z = 1, #lines
  while a <= z and lines[a]:match("^%s*$") do a = a + 1 end
  while z >= a and lines[z]:match("^%s*$") do z = z - 1 end
  local out, blank = {}, 0
  for i = a, z do
    if lines[i]:match("^%s*$") then
      blank = blank + 1
      if blank <= 1 then out[#out + 1] = "" end
    else
      blank = 0
      out[#out + 1] = lines[i]
    end
  end
  return out
end

-- headings: plain text (no bold/italic/underline), keep math
local function plain_inlines(inls)
  return pandoc.Inlines(inls):walk({
    Emph = function(e) return e.content end,
    Strong = function(e) return e.content end,
    Underline = function(e) return e.content end,
  })
end

local function emit_code(kind, lines, out)
  lines = trim(lines)
  if #lines == 0 then return end
  local text = table.concat(lines, "\n")
  if kind == "stata" then
    -- slide output: replaced by the do-file code that produces it
    out[#out + 1] = pandoc.CodeBlock(text, pandoc.Attr("", { "slide-output" }))
  elseif kind == "do" then
    out[#out + 1] = pandoc.CodeBlock(text, pandoc.Attr("", { "stata" }))
  elseif keep_r then
    out[#out + 1] = pandoc.CodeBlock(text, pandoc.Attr("", { "slide-r" }))
  end
end

local function process(blocks)
  local out = {}
  local i = 1
  while i <= #blocks do
    local b = blocks[i]
    local st = style_of(b)
    if st and CODE[st] then
      local kind, lines = CODE[st], {}
      while i <= #blocks and style_of(blocks[i]) and CODE[style_of(blocks[i])] == kind do
        for l in (text_of(blocks[i].content) .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
        i = i + 1
      end
      emit_code(kind, lines, out)
    elseif st and NOTE[st] then
      local inner = {}
      repeat
        for _, x in ipairs(blocks[i].content) do inner[#inner + 1] = x end
        i = i + 1
      until i > #blocks or style_of(blocks[i]) ~= "TB Note"
      out[#out + 1] = pandoc.Div(inner, pandoc.Attr("", { "callout-note" }, { appearance = "simple", icon = "false" }))
    elseif st and DROP[st] then
      i = i + 1
    elseif st == "Head3 - No ToC" or st == "Head 4 - grey - no ToC" then
      local c = plain_inlines(b.content[1] and b.content[1].content or {})
      local t = pandoc.utils.stringify(c)
      -- a continuation slide repeating the previous title is merged into it
      if norm(t) ~= norm(last_title) and norm(t) ~= "" then
        out[#out + 1] = pandoc.Header(4, c)
      end
      i = i + 1
    elseif st then
      for _, x in ipairs(process(b.content)) do out[#out + 1] = x end
      i = i + 1
    else
      if b.t == "Header" then last_title = pandoc.utils.stringify(b.content) end
      out[#out + 1] = b
      i = i + 1
    end
  end
  return out
end

function Span(el)
  local st = el.attributes["custom-style"]
  if not st then return nil end
  if st == "Notice!" or st == "Subtle Emphasis" or st == "Emphasis" then
    return pandoc.Emph(el.content)
  end
  return el.content
end

-- underlining reads as a link on the web
function Underline(el)
  return pandoc.Strong(el.content)
end

function Strong(el)
  el.content = el.content:walk({ Strong = function(s) return s.content end })
  return el
end

function Image(el)
  el.attributes = {}
  el.caption = {}
  el.title = ""
  return el
end

function Header(el)
  if pandoc.utils.stringify(el.content) == "Contents" then return {} end
  el.identifier = ""
  el.classes = {}
  el.content = plain_inlines(el.content)
  return el
end

-- paragraphs left empty (stray breaks, empty bold runs)
function Para(el)
  if pandoc.utils.stringify(el.content):match("^%s*$") then
    for _, x in ipairs(el.content) do
      if x.t == "Image" or x.t == "Math" then return nil end
    end
    return {}
  end
end

function Pandoc(doc)
  keep_r = doc.meta["keep-r"] and pandoc.utils.stringify(doc.meta["keep-r"]) == "true"
  local blocks = {}
  for i, b in ipairs(doc.blocks) do
    if not (b.t == "Table" and i <= 3) then blocks[#blocks + 1] = b end -- title slide
  end
  local function walk(bl)
    local out = {}
    for _, b in ipairs(process(bl)) do
      if b.t == "OrderedList" then b = pandoc.BulletList(b.content) end
      if b.t == "BulletList" then
        for j, item in ipairs(b.content) do b.content[j] = walk(item) end
        local prev = out[#out]
        if prev and prev.t == "BulletList" then -- one list, not two in a row
          for _, item in ipairs(b.content) do prev.content:insert(item) end
          b = nil
        end
      elseif b.t == "Div" or b.t == "BlockQuote" then
        b.content = walk(b.content)
      end
      if b then out[#out + 1] = b end
    end
    return out
  end
  doc.blocks = walk(blocks)
  return doc
end
