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
    "want to match the color limitations of retro hardware such as an Atari ST. It doesn't change",
    "the number of palette entries however, it simply alters existing palette entries.",
    "",
    "The preset options are based on a few popular retro platforms but you can also select a custom",
    "bit-depth. The bit-depth is the number of bits used to represent each color channel.",
    "",
    "The 'Fix dynamic range' option mitigates the brightness compression that otherwise occurs as a",
    "result of reducing bit-depth. The compression is most pronounced with pure whites, which would",
    "not reach full brightness. This option only affects how the sprite is displayed on modern devices",
    "with a full 8-bit color range since it only alters the bits of the shades that cannot be",
    "displayed by the target hardware anyway.",
    "",
    "The 'Use rounding' option rounds (instead of simply truncating bits) to the nearest available",
    "shade, either the darker or brighter one, depending on which is the closest.",
    "This may help to reduce unwanted darkening of the resulting palette."}}
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

      -- The rounding center is used to round the color values to the nearest available shade.
      local rounding_center
      
      if dlg.data.rounding == true then
        rounding_center = 1 << 8 - dlg.data.bits - 1;
      else
        rounding_center = 0
      end

      for i = 0,#pal-1 do
        local color = pal:getColor(i)
                
        color.red = ((math.min(color.red + rounding_center, 255)) & mask) * mply
        color.green = ((math.min(color.green + rounding_center, 255)) & mask) * mply
        color.blue = ((math.min(color.blue + rounding_center, 255)) & mask) * mply

        pal:setColor(i, color)
      end
    end)

    app.refresh()
end

local function selectBits(value)
  dlg:modify{id="bits", value=value}
end

dlg
  :separator{ text="Bit-depth" }
  :combobox{
    id="preset",
    label="Preset:",
    option="Custom",
    options={
      "Atari ST",
      "Atari STE",
      "Commodore Amiga 500",
      "Neo Geo",
      "Nintendo Gameboy Color",
      "Nintendo NES",
      "Nintendo SNES/Super Famicom",
      "Sega Genesis/Megadrive",
      "Custom"
    },
    onchange=function()
      local value = dlg.data.preset
      if value == "Nintendo NES" then
        selectBits(2)
      elseif value == "Atari ST" or value == "Sega Genesis/Megadrive" then
        selectBits(3)
      elseif value == "Atari STE" or value == "Commodore Amiga 500" then
        selectBits(4)
      elseif value == "Neo Geo" or value == "Nintendo Gameboy Color" or value == "Nintendo SNES/Super Famicom" then
        selectBits(5)
      end
    end
  }
  :slider{ id="bits", label="Target bit-depth:", min=1, max=7, value=3,
    onchange=function()
      dlg:modify{id="preset", option="Custom"}
    end
  }
  :separator{ text="Options" }
  :check{ label="Fix dynamic range:", id="fixDR", selected=true }
  :check{ label="Use rounding:", id="rounding", selected=true }

dlg:button{ text="&Help",onclick=function() showHelp() end }
dlg:button{ text="&OK", focus=true, onclick=function() alterPalette() end }
dlg:button{ text="&Cancel",onclick=function() dlg:close() end }

dlg:show{ wait=false }
