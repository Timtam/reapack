-- @metapackage
-- @version 1.0b3
-- @description IntelliQuant
-- @author Toni Barth (Timtam)
-- @links
--   GitHub repository https://github.com/Timtam/IntelliQuant
--   Donation https://paypal.me/ToniRonaldBarth
-- @provides
--   [nomain] timtam_IntelliQuant/smallfolk.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/smallfolk.lua
--   [main=midi_editor] timtam_IntelliQuant/timtam_IntelliQuant quantize.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/timtam_IntelliQuant%20quantize.lua
--   [main=midi_editor] timtam_IntelliQuant/timtam_IntelliQuant set parameters for 16th note quantization.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/timtam_IntelliQuant%20set%20parameters%20for%2016th%20note%20quantization.lua
--   [main=midi_editor] timtam_IntelliQuant/timtam_IntelliQuant set parameters for 16th triplet note quantization.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/timtam_IntelliQuant%20set%20parameters%20for%2016th%20triplet%20note%20quantization.lua
--   [main=midi_editor] timtam_IntelliQuant/timtam_IntelliQuant set parameters for 32th note quantization.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/timtam_IntelliQuant%20set%20parameters%20for%2032th%20note%20quantization.lua
--   [main=midi_editor] timtam_IntelliQuant/timtam_IntelliQuant set parameters for 4th note quantization.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/timtam_IntelliQuant%20set%20parameters%20for%204th%20note%20quantization.lua
--   [main=midi_editor] timtam_IntelliQuant/timtam_IntelliQuant set parameters for 8th note quantization.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/timtam_IntelliQuant%20set%20parameters%20for%208th%20note%20quantization.lua
--   [main=midi_editor] timtam_IntelliQuant/timtam_IntelliQuant set parameters for 8th triplet note quantization.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/timtam_IntelliQuant%20set%20parameters%20for%208th%20triplet%20note%20quantization.lua
--   [main=midi_editor] timtam_IntelliQuant/timtam_IntelliQuant set parameters for quintuplet note quantization.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/timtam_IntelliQuant%20set%20parameters%20for%20quintuplet%20note%20quantization.lua
--   [nomain] timtam_IntelliQuant/timtam_IntelliQuant.lua https://github.com/Timtam/IntelliQuant/raw/v$version/timtam_IntelliQuant/timtam_IntelliQuant.lua
-- @changelog
--   fix flam support introduced in 1.0b2
-- @about
--   A way to quantize notes intelligently.
--   
--   This script will make sure to e.g. pull the notes into the correct direction without snapping them to grid exactly. You can configure a window in which the notes will be quantized.
--   More informative README will follow as soon as 1.0 is out.
