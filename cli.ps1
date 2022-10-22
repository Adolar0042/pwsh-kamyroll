# Kamyroll API PWSH CLI
# Author: Adolar0042

. "$env:USERPROFILE\Desktop\Kamyroll\kamyrollAPI.ps1"

$oldTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Kamyroll CLI"

if (!(Get-InstalledModule -Name PSMenu -ErrorAction SilentlyContinue)) {
    Write-Host "Installing PSMenu Module..."
    Install-Module PSMenu -ErrorAction Stop
}

# Hide Invoke-WebRequest Progress Bar
$ProgressPreference = 'SilentlyContinue'


Function Get-M3U8Resolutions([STRING]$m3u8Url) {
    $i = 0
    $resolutions = @()
    Invoke-WebRequest -Uri $m3u8Url -UseBasicParsing -OutFile "$env:TEMP\m3u8.txt"
    $m3u8 = Get-Content -Path "$env:TEMP\m3u8.txt"
    Remove-Item "$env:TEMP\m3u8.txt"
    foreach ($line in $m3u8.Split("`r`n")) {
        $i++
        if ($i -gt 1 -and $line[0] -eq "#") {
            $resolutions += $line.Split(",")[2].Split("=")[1]
        }
    }
    
    return $resolutions
}

class MenuOption {
    [String]$DisplayName
    [ScriptBlock]$Script
    
    [String]ToString() {
        Return $This.DisplayName
    }
}
    
function New-MenuItem([String]$DisplayName, [ScriptBlock]$Script) {
    $MenuItem = [MenuOption]::new()
    $MenuItem.DisplayName = $DisplayName
    $MenuItem.Script = $Script
    Return $MenuItem
}
    
    

Clear-Host
$query = Read-Host "Search"
if ($query.Split("/")[3] -eq "series") {
    Write-Host "Crunchyroll series link detected"
    $seriesID = $query.Split("/")[4]
}
elseif ($query.Split("/")[3] -eq "watch") {
    Write-Host "Crunchyroll episode link detected"
    $episodeID = $query.Split("/")[4]
    $episodeName = $query.Split("/")[5]
}
else {
    Write-Host "Searching for ""$query"" ..."
    $searchResult = Search -query $query -limit 5
    [INT]$totalResults = 0
    foreach ($type in $searchResult.items) {
        foreach ($entry in $type.items) {
            $i++
        }
        $totalResults = $i
    }
    Remove-Variable -Name i
    if ($totalResults -eq 0) {
        Write-Host "No results found" -ForegroundColor Red
        break
    }
    Clear-Host

    # Search Result Menu
    Write-Host "Searched: ""$query""`r`nTotal Search Results: $totalResults`r`n`r`n" -ForegroundColor Green
    $result = Show-Menu -MenuItems $searchResult.items.items -Callback {
        $lastTop = [Console]::CursorTop
        [System.Console]::SetCursorPosition(0, 0)
        Write-Host "Searched: ""$query""`r`nTotal Search Results: $totalResults`r`n`r`n" -ForegroundColor Green
        [System.Console]::SetCursorPosition(0, $lastTop)
    } -MenuItemFormatter { 
        $name = if ($Args.title.Length -gt ($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 6)) {
            $Args.title.Substring(0, ($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 9)) + "..."
        }
        else {
            $Args.title + " " * (($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 6) - $Args.title.Length)
        }
        $name
    }
    Clear-Host
}


if (($result.media_type -eq "series") -or ($NULL -ne $seriesID)) {
    $id = if ($NULL -ne $seriesID) { $seriesID }else { $result.id }
    Write-Host "Getting seasons ..." -ForegroundColor Green
    $seasons = Seasons -seriesID $id
    if ($Null -eq $seasons.items) {
        Write-Host "No seasons found" -ForegroundColor Red
        break
    }
    Clear-Host

    # Season Select Menu
    Write-Host "Select an season`r`n" -ForegroundColor Green
    $season = Show-Menu -MenuItems $seasons.items -Callback {
        $lastTop = [Console]::CursorTop
        [System.Console]::SetCursorPosition(0, 0)
        Write-Host "Select an season`r`n" -ForegroundColor Green
        [System.Console]::SetCursorPosition(0, $lastTop)
    } -MenuItemFormatter { 
        $name = if ($Args.title.Length -gt ($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 6)) {
            $Args.title.Substring(0, ($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 9)) + "..."
        }
        else {
            $Args.title + " " * (($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 6) - $Args.title.Length)
        }
        $name
    }

    $media = $season
    Clear-Host
}
elseif ($result.media_type -eq "movie_listing") {
    Write-Host "Getting movies ..." -ForegroundColor Green
    $movies = Movies -moviesID $result.id
    Clear-Host
    Write-Host "Select an movie`r`n" -ForegroundColor Green
    $movie = Show-Menu -MenuItems $movies.items -Callback {
        $lastTop = [Console]::CursorTop
        [System.Console]::SetCursorPosition(0, 0)
        Write-Host "Select an movie`r`n" -ForegroundColor Green
        [System.Console]::SetCursorPosition(0, $lastTop)
    } -MenuItemFormatter { 
        $name = if ($Args.title.Length -gt ($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 6)) {
            $Args.title.Substring(0, ($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 9)) + "..."
        }
        else {
            $Args.title + " " * (($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 6) - $Args.title.Length)
        }
        $name
    }

    [INT]$i = 0
    Clear-Host
    $media = $movie
}
elseif ($NULL -eq $episodeID) {
    Write-Host "Media type not supported. $($result.media_type) | $($result)" -ForegroundColor Red
    break
}


Clear-Host

if ($Null -ne $episodeID) {
    Write-Host "Getting streams ..." -ForegroundColor Green
    $streams = Streams -mediaID $episodeID
    if ($Null -eq $streams) {
        Write-Host "No streams found" -ForegroundColor Red
        break
    }
    Clear-Host

    Do {
        Clear-Host

        # Streams Select Menu (Audio, Subs)
        Write-Host "Select an stream`r`n" -ForegroundColor Green
        $stream = Show-Menu -MenuItems $streams.streams -Callback {
            $lastTop = [Console]::CursorTop
            [System.Console]::SetCursorPosition(0, 0)
            [System.Console]::SetCursorPosition(0, $lastTop)
        } -MenuItemFormatter { 
            "Audio: $($Args.audio_locale) " + $(if ($Args.hardsub_locale -ne "") { "Hardsub: $($Args.hardsub_locale)" }else { "Hardsub: None" })
        }

        $streamRes = Get-M3U8Resolutions $stream.url
        Clear-Host
        Write-Host "Choose resolution`r`n" -ForegroundColor Green
        $res = Show-Menu -MenuItems $streamRes -Callback {
            $lastTop = [Console]::CursorTop
            [System.Console]::SetCursorPosition(0, 0)
            Write-Host "Choose resolution`r`n" -ForegroundColor Green
            [System.Console]::SetCursorPosition(0, $lastTop)
        }
        Invoke-WebRequest -Uri $stream.url -UseBasicParsing -OutFile "$env:TEMP\m3u8.txt" | Out-Null
        $m3u8 = Get-Content -Path "$env:TEMP\m3u8.txt"
        Remove-Item "$env:TEMP\m3u8.txt" | Out-Null 
        $next = $false
        foreach ($line in $m3u8.Split("`r`n")) {
            if ($next -eq $true) {
                $url = $line
                $next = $false
                Write-Host $url -ForegroundColor Green
            }
            else {
                if ($line.Contains($res)) {
                    $next = $true
                } 
                else {
                    $next = $false
                }
            }
        }

        [INT]$i = 0
        New-Item -Path "$env:USERPROFILE\Desktop\Kamyroll\anime\Unknown Series\$episodeName" -ItemType Directory -Force | Out-Null
        Clear-Host

        if ($stream.hardsub_locale -eq "") {
            $subtitles = $streams.subtitles
            if ($Null -eq $subtitles) {
                Write-Host "No subtitles found" -ForegroundColor Red
                break
            }

            # Subtitles Select Menu
            Write-Host "Select subtitle(s)`r`nSpace -> Select`r`nEnter -> Confirm Selection`r`n" -ForegroundColor Green
            $subtitle = Show-Menu -MenuItems $subtitles -Callback {
                $lastTop = [Console]::CursorTop
                [System.Console]::SetCursorPosition(0, 0)
                [System.Console]::SetCursorPosition(0, $lastTop)
            } -MenuItemFormatter { 
                $Args.locale
            } -MultiSelect
    
            if ($subtitle.count -eq 0 -and $subtitle.url -ne "") {
                Invoke-WebRequest -Uri $subtitle.url -OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\Unknown Series\$episodeName\[$($subtitle.locale)] $($episodeName).ass"
            }
            elseif ($subtitle.count -ne 0) {
                foreach ($sub in $subtitle) {
                    Invoke-WebRequest -Uri $sub.url -OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\Unknown Series\$episodeName\[$($sub.locale)] $($episodeName).ass"
                }
            }
        }
        # $url is the url with chosen resolution
        # TODO: Add m3u8 to mp4
        Invoke-WebRequest -UseBasicParsing –Uri $url –OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\Unknown Series\$episodeName\$($episode.title).m3u8"
        Invoke-Item "$env:USERPROFILE\Desktop\Kamyroll\anime\Unknown Series\$episodeName"
    }
    While ($true)
}
else {
    # $mediaTable = $media.episodes
    if ($Null -eq $media.episodes) {
        Write-Host "No episodes found" -ForegroundColor Red
        break
    }
    Do {
        Clear-Host
        Write-Host "Select an episode`r`n" -ForegroundColor Green

        # Episode Select Menu
        $episode = Show-Menu -MenuItems $media.episodes -Callback {
            $lastTop = [Console]::CursorTop
            [System.Console]::SetCursorPosition(0, 0)
            [System.Console]::SetCursorPosition(0, $lastTop)
        } -MenuItemFormatter { 
            if ($Args.episode -ne "") { $name = "[$($Args.episode)] " }
            $name = if (($name + $Args.title).Length -gt ($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 6)) {
                    ($name + $Args.title).Substring(0, ($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 9)) + "..."
            }
            else {
                $name + $Args.title + " " * (($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 6) - ($name + $Args.title).Length)
            }
            $name
        }
    
        Clear-Host
        Write-Host "Getting streams..." -ForegroundColor Green
        $streams = Streams -mediaID $episode.id
        if ($Null -eq $streams.streams) {
            Write-Host "No streams found" -ForegroundColor Red
            break
        }
        Clear-Host

        # Streams Select Menu (Audio, Subs)
        Write-Host "Select an stream`r`n" -ForegroundColor Green
        $stream = Show-Menu -MenuItems $streams.streams -Callback {
            $lastTop = [Console]::CursorTop
            [System.Console]::SetCursorPosition(0, 0)
            [System.Console]::SetCursorPosition(0, $lastTop)
        } -MenuItemFormatter { 
            "Audio: $($Args.audio_locale) " + $(if ($Args.hardsub_locale -ne "") { "Hardsub: $($Args.hardsub_locale)" }else { "Hardsub: None" })
        }

        $streamRes = Get-M3U8Resolutions $stream.url
        Clear-Host
        Write-Host "Choose resolution`r`n" -ForegroundColor Green
        $res = Show-Menu -MenuItems $streamRes -Callback {
            $lastTop = [Console]::CursorTop
            [System.Console]::SetCursorPosition(0, 0)
            Write-Host "Choose resolution`r`n" -ForegroundColor Green
            [System.Console]::SetCursorPosition(0, $lastTop)
        }
        Invoke-WebRequest -Uri $stream.url -UseBasicParsing -OutFile "$env:TEMP\m3u8.txt" | Out-Null
        $m3u8 = Get-Content -Path "$env:TEMP\m3u8.txt"
        Remove-Item "$env:TEMP\m3u8.txt" | Out-Null 
        $next = $false
        foreach ($line in $m3u8.Split("`r`n")) {
            if ($next -eq $true) {
                $url = $line
                $next = $false
                Write-Host $url -ForegroundColor Green
            }
            else {
                if ($line.Contains($res)) {
                    $next = $true
                } 
                else {
                    $next = $false
                }
            }
        }

        [INT]$i = 0
        New-Item -Path "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)" -ItemType Directory -Force | Out-Null
        Clear-Host

        if ($stream.hardsub_locale -eq "") {
            $subtitles = $streams.subtitles
            if ($Null -eq $subtitles) {
                Write-Host "No subtitles found" -ForegroundColor Red
                break
            }

            # Subtitles Select Menu
            Write-Host "Select subtitle(s)`r`nSpace -> Select`r`nEnter -> Confirm Selection`r`n" -ForegroundColor Green
            $subtitle = Show-Menu -MenuItems $subtitles -Callback {
                $lastTop = [Console]::CursorTop
                [System.Console]::SetCursorPosition(0, 0)
                [System.Console]::SetCursorPosition(0, $lastTop)
            } -MenuItemFormatter { 
                $Args.locale
            } -MultiSelect

            if ($subtitle.count -eq 0 -and $subtitle.url -ne "") {
                Invoke-WebRequest -Uri $subtitle.url -OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)\[$($subtitle.locale)] $($episode.title).ass"
            }
            elseif ($subtitle.count -ne 0) {
                foreach ($sub in $subtitle) {
                    Invoke-WebRequest -Uri $sub.url -OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)\[$($sub.locale)] $($episode.title).ass"
                }
            }
        }
        # $url is the url with chosen resolution
        Invoke-WebRequest -UseBasicParsing –Uri $url –OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)\$($episode.title).m3u8"
        Invoke-Item "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)"
    }
    While ($true)
}

$Host.UI.RawUI.WindowTitle = $oldTitle

Remove-Variable * -ErrorAction SilentlyContinue
