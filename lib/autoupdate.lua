-- Program Lib
-- Author: Navatusein
-- License: MIT
-- Version: 3.8

local internet   = require("internet")
local shell      = require("shell")
local filesystem = require("filesystem")
local computer   = require("computer")
local term       = require("term")

---@class ProgramVersion
---@field programVersion string

local function getLatestVersion(repository)
  local request = internet.request(
    "https://raw.githubusercontent.com/" .. repository .. "/refs/heads/main/version.lua"
  )
  local result = ""
  for chunk in request do
    result = result .. chunk
  end
  return load(result)()
end

local function isUpdateNeeded(version, repository)
  if not version or not internet then return false, nil end

  local ok, remote = pcall(getLatestVersion, repository)

  if not ok or not remote then return false, nil end
  if not version.programVersion or not remote.programVersion then return false, nil end

  local current = version.programVersion:gsub("[%D]", "")
  local latest  = remote.programVersion:gsub("[%D]", "")

  return latest ~= current, remote
end

local function tryDownloadTar()
  if filesystem.exists("/bin/tar.lua") then return end

  shell.setWorkingDirectory("/usr/man")
  shell.execute("wget -fq https://raw.githubusercontent.com/mpmxyz/ocprograms/master/usr/man/tar.man")
  shell.setWorkingDirectory("/bin")
  shell.execute("wget -fq https://raw.githubusercontent.com/mpmxyz/ocprograms/master/home/bin/tar.lua")
end

local function downloadAndInstall(repository, archiveName)
  local url = "https://github.com/" .. repository .. "/releases/latest/download/" .. archiveName .. ".tar"
  shell.setWorkingDirectory("/home")
  shell.execute("wget -fq " .. url .. " program.tar")
  shell.execute("tar -xf program.tar")
  shell.execute("rm program.tar")
end

---Check for updates and installs.
---@param version ProgramVersion
---@param repository string
---@param archiveName string
local function autoUpdate(version, repository, archiveName)
  term.clear()
  term.setCursor(1, 1)
  term.write("Checking for updates...\n")

  local updateNeeded, remote = isUpdateNeeded(version, repository)

  if not updateNeeded or not remote then
    term.write("Already up to date.\n")
    return
  end

  term.clear()
  term.write("New version available: " .. remote.programVersion .. " \n")

  tryDownloadTar()

  term.clear()
  term.write("Installing " .. remote.programVersion .. "...\n")
  downloadAndInstall(repository, archiveName)
  term.write("Done.\n")

  computer.shutdown(true)
end

return autoUpdate
