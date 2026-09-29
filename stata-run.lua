-- stata-run.lua
--
-- A Pandoc/Quarto filter for Stata output produced by dyntext.
--
-- In the page sources, Stata code is written inside a fenced block of class
-- "stata-run":
--
--     ```{.stata-run}
--     <<dd_do>>
--     sysuse auto, clear
--     regress price mpg
--     <</dd_do>>
--     ```
--
-- dyntext (run by build.do) replaces the <<dd_do>> tags with what Stata's
-- Results window shows: each command prefixed by ". " (continuation lines by
-- "> "), followed by its output. This filter then splits that text into
-- alternating blocks:
--
--   * command lines  -> a normal code block with class "stata", so Quarto
--                       syntax-highlights it and adds a copy button. The
--                       ". " / "> " prompts are removed, so what is copied is
--                       runnable Stata code.
--   * output lines   -> a code block with class "stata-output", styled by
--                       theme.scss.
--
-- If the block contains no prompt lines (for example <<dd_do: nocommands>> or
-- noprompt), the whole block is treated as output. Non-HTML formats are left
-- untouched.

local function is_blank(s)
  return s:match("^%s*$") ~= nil
end

local function trim_blank_lines(lines)
  local first, last = 1, #lines
  while first <= last and is_blank(lines[first]) do first = first + 1 end
  while last >= first and is_blank(lines[last]) do last = last - 1 end
  local out = {}
  for i = first, last do out[#out + 1] = lines[i] end
  return out
end

local function make_block(kind, lines)
  lines = trim_blank_lines(lines)
  if #lines == 0 then return nil end
  local text = table.concat(lines, "\n")
  if kind == "cmd" then
    return pandoc.CodeBlock(text, pandoc.Attr("", { "stata", "stata-cmd" }))
  else
    return pandoc.CodeBlock(text, pandoc.Attr("", { "stata-output" }))
  end
end

function CodeBlock(el)
  if not el.classes:includes("stata-run") then return nil end
  if not FORMAT:match("html") then
    -- leave as a plain code block elsewhere (pdf, docx, ...)
    el.classes = { "text" }
    return el
  end

  local lines = {}
  for line in (el.text .. "\n"):gmatch("(.-)\r?\n") do
    lines[#lines + 1] = line
  end

  local has_prompt = false
  for _, l in ipairs(lines) do
    if l:match("^%. %S") then has_prompt = true; break end
  end

  local blocks = {}
  local function push(b) if b then blocks[#blocks + 1] = b end end

  if not has_prompt then
    push(make_block("out", lines))
  else
    -- Walk the lines, grouping consecutive commands (with no output between
    -- them) into one command block and everything else into output blocks.
    -- Blank lines are held back ("pending") so that they separate output
    -- lines but do not split two adjacent commands into two blocks.
    local kind, buf, pending = nil, {}, 0
    for _, l in ipairs(lines) do
      if is_blank(l) then
        pending = pending + 1
      else
        local k, txt
        if l:match("^%. %S") then
          k, txt = "cmd", l:sub(3)
        elseif kind == "cmd" and pending == 0 and l:match("^> ") then
          -- continuation of a long command broken with ///
          k, txt = "cmd", l:sub(3)
        else
          k, txt = "out", l
        end
        if kind ~= nil and k ~= kind then
          push(make_block(kind, buf))
          buf = {}
        elseif kind == "out" then
          for _ = 1, pending do buf[#buf + 1] = "" end
        end
        kind = k
        buf[#buf + 1] = txt
        pending = 0
      end
    end
    push(make_block(kind, buf))
  end

  if #blocks == 0 then return {} end
  return pandoc.Div(blocks, pandoc.Attr("", { "stata-run" }))
end
