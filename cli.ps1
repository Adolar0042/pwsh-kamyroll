# Kamyroll API PWSH CLI
# Author: Adolar0042

<#   Default Folder
Should contain:
- kamyrollAPI.ps1

Structure:
$defaultFolder 
|_ kamyrollAPI.ps1
|_ anime
| |_<Anime Title>
| | |_ <Episode Number>
| |   |_ <Episode Title>.m3u8
| |   |_ [<locale>] <Episode Title>.ass
| |_ Unknown Series                 (this folder contains episodes that were downloaded via lloryhcnurC url)
|   |_ <Episode Title>
|     |_ <Episode Title>.m3u8
|     |_ [<locale>] <Episode Title>.ass
|_ token
  |_ token_type
  |_ access_token
  |_ created_at
  |_ expires_in
#>
$defaultFolder = "$env:USERPROFILE\Desktop\Kamyroll"

. "$defaultFolder\kamyrollAPI.ps1"

$oldTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Kamyroll CLI"

if (!(Get-InstalledModule -Name PSMenu -ErrorAction SilentlyContinue)) {
    Write-Host "Installing PSMenu Module, this is a necessary dependency of the CLI ..."
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

Function Normalize-Name([STRING]$string) {
    return $string.Replace("/", " ").Replace(":", " ").Replace("*", " ").Replace("?", " ").Replace("<", " ").Replace(">", " ").Replace("|", " ").Replace("""", " ")
}

Function Get-Episode($media){
    # Episode Select Menu
    Write-Host "Select an episode`r`n" -ForegroundColor Green
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
    return $episode
}

Function Get-Stream($episode, [BOOLEAN]$isID = $false) {
    Write-Host "Getting streams..." -ForegroundColor Green
    if ($isID -eq $true) {
        $streams = Streams -mediaID $episode
    }
    else {
        $streams = Streams -mediaID $episode.id
        if ($Null -eq $streams.streams) {
            Write-Host "No streams found" -ForegroundColor Red
            break
        }
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
    Clear-Host
    return $streams, $stream
}

Function Get-ResolutionUrl($streamRes) {
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
    Clear-Host
    return $url
}

Function Get-SoftSubs($streams) {
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
    Clear-Host
    return $subtitle
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
            $name = "$($Args.title) $(if($Args.media_type -eq "movie_listing"){"[Movie]"}elseif($Args.media_type -eq "series"){"[Series]"})"
            $name = $name + " " * (($Host.UI.RawUI.WindowSize.Width / 3 * 2 - 6) - $name.Length)
            $name
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
    $media = Movies -moviesID $result.id

    Clear-Host
    # Get-Streams $media.items $media.items
    $streams, $stream = Get-Stream $media.items
    $streamRes = Get-M3U8Resolutions $stream.url
    $url = Get-ResolutionUrl $streamRes
    $subtitle = Get-SoftSubs $streams
    if ($stream.hardsub_locale -eq "") {
        $subtitle = Get-SoftSubs $streams

        if ($subtitle.count -eq 0 -and $subtitle.url -ne "") {
            Invoke-WebRequest -Uri $subtitle.url -OutFile "$defaultFolder\anime\$(Normalize-Name $media.title)\$($episode.episode)\[$($subtitle.locale)] $(Normalize-Name $episode.title).ass"
        }
        elseif ($subtitle.count -ne 0) {
            foreach ($sub in $subtitle) {
                Invoke-WebRequest -Uri $sub.url -OutFile "$defaultFolder\anime\$(Normalize-Name $media.title)\$($episode.episode)\[$($sub.locale)] $(Normalize-Name $episode.title).ass"
            }
        }
    }
    break
}
elseif ($NULL -eq $episodeID) {
    Write-Host "Media type not supported. $($result.media_type) | $($result)" -ForegroundColor Red
    break
}


Clear-Host

if ($Null -ne $episodeID) {
    $streams, $stream = Get-Stream $episodeID $true
    $streamRes = Get-M3U8Resolutions $stream.url
    $url = Get-ResolutionUrl $streamRes

    New-Item -Path "$defaultFolder\anime\Unknown Series\$(Normalize-Name $episodeName)" -ItemType Directory -Force | Out-Null

    if ($stream.hardsub_locale -eq "") {
        $subtitles = $streams.subtitles
        if ($Null -eq $subtitles) {
            Write-Host "No subtitles found" -ForegroundColor Red
            break
        }
        $subtitle = Get-SoftSubs $streams    
        if ($subtitle.count -eq 0 -and $subtitle.url -ne "") {
            Invoke-WebRequest -Uri $subtitle.url -OutFile "$defaultFolder\anime\Unknown Series\$(Normalize-Name $episodeName)\[$($subtitle.locale)] $(Normalize-Name $episodeName).ass"
        }
        elseif ($subtitle.count -ne 0) {
            foreach ($sub in $subtitle) {
                Invoke-WebRequest -Uri $sub.url -OutFile "$defaultFolder\anime\Unknown Series\$(Normalize-Name $episodeName)\[$($sub.locale)] $(Normalize-Name $episodeName).ass"
            }
        }
    }
    # $url is the url with chosen resolution
    # TODO: Add m3u8 to mp4
    Invoke-WebRequest -UseBasicParsing –Uri $url –OutFile "$defaultFolder\anime\Unknown Series\$(Normalize-Name $episodeName)\$(Normalize-Name $episode.title).m3u8"
    Invoke-Item "$defaultFolder\anime\Unknown Series\$(Normalize-Name $episodeName)"
}
else {
    if ($Null -eq $media.episodes) {
        Write-Host "No episodes found" -ForegroundColor Red
        break
    }
    Do {
        Clear-Host
        $episode = Get-Episode $media
        $streams, $stream = Get-Stream $episode
        $streamRes = Get-M3U8Resolutions $stream.url
        $url = Get-ResolutionUrl $streamRes
    
        New-Item -Path "$defaultFolder\anime\$(Normalize-Name $media.title)\$($episode.episode)" -ItemType Directory -Force | Out-Null
    
        if ($stream.hardsub_locale -eq "") {
            $subtitle = Get-SoftSubs $streams
    
            if ($subtitle.count -eq 0 -and $subtitle.url -ne "") {
                Invoke-WebRequest -Uri $subtitle.url -OutFile "$defaultFolder\anime\$(Normalize-Name $media.title)\$($episode.episode)\[$($subtitle.locale)] $(Normalize-Name $episode.title).ass"
            }
            elseif ($subtitle.count -ne 0) {
                foreach ($sub in $subtitle) {
                    Invoke-WebRequest -Uri $sub.url -OutFile "$defaultFolder\anime\$(Normalize-Name $media.title)\$($episode.episode)\[$($sub.locale)] $(Normalize-Name $episode.title).ass"
                }
            }
        }
        # $url is the url with chosen resolution
        Invoke-WebRequest -UseBasicParsing –Uri $url –OutFile "$defaultFolder\anime\$(Normalize-Name $media.title)\$($episode.episode)\$(Normalize-Name $episode.title).m3u8"
        Invoke-Item "$defaultFolder\anime\$(Normalize-Name $media.title)\$($episode.episode)"
    
    }
    While ($true)
}

$Host.UI.RawUI.WindowTitle = $oldTitle

Remove-Variable * -ErrorAction SilentlyContinue
