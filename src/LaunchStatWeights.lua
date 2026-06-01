#@ SimpleGraphic
-- Path of Building
--
-- Stat weight report launcher.
-- Starts the normal PoB app, imports the cached character, writes a report,
-- then exits.

POB_STAT_WEIGHT_RUN = true

LoadModule("Launch")

local originalOnFrame = launch.OnFrame
local reportStarted = false

local function writeFailure(errMsg)
	local outDir = os.getenv("POB_STAT_OUTPUT_DIR") or "stat-weight-reports"
	MakeDir(outDir)
	local path = outDir .. "/latest-error.txt"
	local f = io.open(path, "w")
	if f then
		f:write(tostring(errMsg), "\n")
		f:close()
	end
	ConPrintf("Stat weight report failed: %s", tostring(errMsg))
end

function launch:OnFrame(...)
	if originalOnFrame then
		originalOnFrame(self, ...)
	end
	if reportStarted then
		return
	end
	if not (self.main and self.main.modes and self.main.modes["BUILD"]) then
		return
	end
	reportStarted = true

	local ok, resultOrErr = pcall(function()
		local report = LoadModule("Modules/StatWeightReport")
		return report.Generate({
			inputPath = os.getenv("POB_STAT_INPUT"),
			outputDir = os.getenv("POB_STAT_OUTPUT_DIR"),
			mainSkill = os.getenv("POB_STAT_MAIN_SKILL"),
			dpsMetric = os.getenv("POB_STAT_DPS_METRIC"),
			calibrationPath = os.getenv("POB_STAT_CALIBRATION"),
		})
	end)

	if ok then
		ConPrintf("Stat weight report written: %s", resultOrErr.markdownPath or "")
	else
		writeFailure(resultOrErr)
	end
	Exit()
end
