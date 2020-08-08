----------------------------------------------------------------------
-- Reduces the bit-depth of the palette colors.
----------------------------------------------------------------------
-- Author:  Sandor Drieënhuizen
-- Source:  https://github.com/sandord/aseprite-scripts
-- License: MIT
----------------------------------------------------------------------

local spr = app.activeSprite

if not spr then
  return app.alert("There is no active sprite")
end

local dlg = Dialog("Reduce palette bit-depth")

local function showHelp()
  app.alert{title="Help", text={
    "This extension reduces the bit-depth of each palette color, which could be desirable if you",
    "want to match the color limitations of retro hardware such as an Atari ST.",
    "It doesn't reduce the number of palette entries, it simply alters existing palette entries.",
    "",
    "The Atari ST has 3 bits per primary color (512 possible colors, #000-#777).",
    "The Atari STE and the Commodore Amiga have 4 bits (4096 possible colors, #000-#fff).",
    "",
    "The option to fix the dynamic range ensures that the brightest white becomes #ffffff,",
    "while retaining pure blacks. This doesn't matter when processing the sprite for use on",
    "reduced bit-depth hardware (assuming that the lower bits are ignored) but corrects the reduced",
    "brightness while designing in Aseprite and/or viewing the sprite on a modern device."}}
end

local function alterPalette()
  dlg:close()
  
  app.transaction(
    function()
      local pal = spr.palettes[1]
      local mask = (0xff << (8 - dlg.data.bits)) & 0xff

      -- The multiplier will optionally fix the dynamic range.
      local mply

      if dlg.data.fixDR == true then
        mply = 0xff / mask
      else
        mply = 1
      end
        
      for i = 0,#pal-1 do
        local color = pal:getColor(i)
        
        color.red = (color.red & mask) * mply
        color.green = (color.green & mask) * mply
        color.blue = (color.blue & mask) * mply

        pal:setColor(i, color)
      end
    end)

    app.refresh()
end

local function selectBits(value)
  dlg:modify{id="bits", value=value}
  dlg:modify{id="bits", enabled=false}
end

dlg
  :separator{ text="Options" }
  :radio{ label="Preset:", text="Atari ST", id="preset", selected=true, onclick=function() selectBits(3) end }
  :newrow()
  :radio{ text="Atari STE", id="preset", onclick=function() selectBits(4) end }
  :newrow()
  :radio{ text="Commodore Amiga", id="preset", onclick=function() selectBits(4) end }
  :newrow()
  :radio{ text="Custom:", id="preset", onclick=function() dlg:modify{id="bits", enabled=true} end }
  :newrow()
  :slider{ id="bits", label="Bits:", min=1, max=7, value=3, enabled=false}
  :check{ label="Fix dynamic range:", id="fixDR", selected=true }

dlg:button{ text="&Help",onclick=function() showHelp() end }
dlg:button{ text="&OK", focus=true, onclick=function() alterPalette() end }
dlg:button{ text="&Cancel",onclick=function() dlg:close() end }

dlg:show{ wait=false }
