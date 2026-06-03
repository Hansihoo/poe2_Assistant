#@ SimpleGraphic
-- Path of Building
--
-- Korean display launcher.
-- Installs a render-time translation layer, then starts the upstream launcher.
--

POB_KOREAN_DISPLAY = true

local localization = LoadModule("Modules/Localization")
local enabled = os.getenv("POB_KO_DISABLE") ~= "1" and os.getenv("POB_KO_ENABLE") ~= "0"
localization.Install({
	language = "ko",
	enabled = enabled,
})

LoadModule("Launch")
