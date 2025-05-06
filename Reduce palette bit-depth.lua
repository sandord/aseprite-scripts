----------------------------------------------------------------------
-- Reduces the bit-depth of the palette colors.
----------------------------------------------------------------------
-- Author:  Sandor Drieënhuizen
-- Source:  https://github.com/sandord/aseprite-scripts
-- License: MIT
----------------------------------------------------------------------

local spr = app.sprite

if not spr then
  return app.alert("This script requires a sprite to be open.")
end

local pal = spr.palettes[1]
local originalPal = Palette(#pal)

for i = 0, #pal - 1 do
  originalPal:setColor(i, pal:getColor(i))
end

local changesMade = false

local previewItemLimit = 256
local previewItemCount = math.min(#pal, previewItemLimit)
local previewItemMaxSize = 9
local previewItemSize = math.min(2048 / previewItemCount, previewItemMaxSize)
local previewWidth = 75
local previewHeight = ((previewItemCount / (previewWidth / previewItemSize)) + 1) * (previewItemSize + 1)

local dlg = Dialog("Reduce palette bit-depth")

local function showHelp()
  app.alert{
    title="Help",
    text={
      "This script reduces the bit-depth of each palette color, which could be desirable if you",
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
      "This may help to reduce unwanted darkening of the resulting palette."
    }
  }
end

local function apply()
  if changesMade == true then
    app.undo()
  end

  local mask = (0xff << (8 - dlg.data.bits)) & 0xff
  
  -- The multiplier is used to fix the dynamic range.
  local mply

  if dlg.data.fixDR == true then
    mply = 0xff / mask
  else
    mply = 1
  end

  -- The rounding center is used to round the color values to the nearest available shade.
  local rounding_center
  
  if dlg.data.rounding == true then
    rounding_center = (1 << 8 - dlg.data.bits - 1) - 1;
  else
    rounding_center = 0
  end

  app.transaction(
    "Change palette bit-depth",
    function()
      for i = 0, #pal - 1 do
        local color = pal:getColor(i)
                
        color.red = ((math.min(color.red + rounding_center, 255)) & mask) * mply
        color.green = ((math.min(color.green + rounding_center, 255)) & mask) * mply
        color.blue = ((math.min(color.blue + rounding_center, 255)) & mask) * mply
        
        pal:setColor(i, color)
      end
    end
  )

  changesMade = true
  dlg:repaint()
end

local function selectBits(value)
  dlg:modify{id="bits", value=value}
  apply()
end

local function paintPalettePreview(ev, xOffset, previewChanges)
  local gc = ev.context
  local x = xOffset
  local y = 0
  local color
        
  for i = 0, previewItemCount - 1 do

    if previewChanges == true then
      color = pal:getColor(i)
    else
      color = originalPal:getColor(i)
    end

    gc.color = color
    gc:fillRect(Rectangle(x + 1, y + 1, previewItemSize - 1, previewItemSize - 1))

    gc.color = Color(0, 0, 0)
    gc:strokeRect(Rectangle(x, y, previewItemSize + 1, previewItemSize + 1))
    
    x = x + previewItemSize
    
    if x > xOffset + previewWidth - previewItemSize then
      x = xOffset
      y = y + previewItemSize
    end
  end
end

dlg
  :separator{ text="Palette preview (before/after)" }
  :canvas{
    id="paletteCanvas",
    width=previewWidth,
    height=previewHeight,
    onpaint=function(ev)
      paintPalettePreview(ev, 0, false)
      paintPalettePreview(ev, previewWidth + 4, true)
    end
  }
  :label{
    text="Preview limited to " .. tostring(previewItemLimit) .. " colors.",
    visible=#pal > previewItemLimit
  }
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
      apply()
    end
  }  
  :separator{ text="Options" }
  :check{ label="Fix dynamic range:", id="fixDR", selected=false, onclick=function() apply() end }
  :check{ label="Use rounding:", id="rounding", selected=false, onclick=function() apply() end }

dlg:button{ text="&Help",onclick=function() showHelp() end }

dlg:button{ text="&OK", focus=true, onclick=function()
  apply()
  dlg:close()
  end
}

dlg:button{ text="&Cancel",onclick=function() 
  app.undo()
  dlg:close()
  end
}

dlg:show{ wait=true }
