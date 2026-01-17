-- Simple GitHub repo downloader
-- SpartanSf 2026

local REPO_OWNER = "SpartanSf"
local REPO_NAME = "ion2d"
local BRANCH = "main"
local API_ROOT = "https://api.github.com/repos/" .. REPO_OWNER .. "/" .. REPO_NAME .. "/contents/"

local HEADERS = {
	["User-Agent"] = "ComputerCraft",
	["Accept"] = "application/vnd.github.v3+json",
}

local function http_get(url)
	local res, err = http.get(url, HEADERS)
	if not res then
		local tmp = fs.open("tmp.txt", "w")
		tmp.write(url)
		tmp.close()
		error("HTTP request failed: " .. err)
	end
	local data = res.readAll()
	res.close()
	return data
end

local function download_file(url, path)
	print("Downloading file:", path)
	local data = http_get(url)
	local f = fs.open(path, "wb")
	f.write(data)
	f.close()
end

local function process_dir(api_path, local_path)
	if not fs.exists(local_path) then
		fs.makeDir(local_path)
	end

	local url = api_path
	if not api_path:find("?ref=") then
		url = api_path .. "?ref=" .. BRANCH
	end

	local json = textutils.unserializeJSON(http_get(url))
	if not json then
		error("Failed to parse JSON for " .. api_path)
	end

	for _, item in ipairs(json) do
		if item.name ~= "LICENSE" then
			local out_path = fs.combine(local_path, item.name)

			if item.type == "file" then
				download_file(item.download_url, out_path)
			elseif item.type == "dir" then
				process_dir(item.url, out_path)
			end
		end
	end
end

print("Installing Ion2D...")
process_dir(API_ROOT, "/")
print("Ion2D installation complete.")
