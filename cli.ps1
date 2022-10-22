# Kamyroll API PWSH CLI
# Author: Adolar0042

# The "Function Kamyroll" is the main function, 
# this is intended for being automatically started when powershell is opened, 
# so you can use the CLI by simply typing "kamyroll" in the powershell window.
# If you want to use the CLI without starting it automatically,
# just remove the "Function Kamyroll {" and the "}" at the end of the script.
Function Kamyroll {
    
    . "$env:USERPROFILE\Desktop\Kamyroll\kamyrollAPI.ps1"

    $oldTitle = $Host.UI.RawUI.WindowTitle
    $Host.UI.RawUI.WindowTitle = "Kamyroll CLI"
    #$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


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
        $searchResult = Search -query $query -limit 5
        [INT]$totalResults = 0
        foreach ($type in $searchResult.items) {
            foreach ($entry in $type.items) {
                $i++
            }
            $totalResults = $i
        }
        [INT]$i = 0
        Write-Host "`r`nTotal Search Result: $($totalResults)`r`n" -ForegroundColor Green
        $resultTable = $searchResult.items | Select-Object -ExpandProperty items | Select-Object -Property title, id, media_type
        if ($Null -eq $resultTable) {
            Write-Host "No results found" -ForegroundColor Red
            break
        }
        foreach ($title in $resultTable) {
            $i++
            $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
        }
        $resultTable | Format-Table 'Index', 'title', 'media_type', 'id' -AutoSize
        $index = Read-Host "Select Index"
        $result = $resultTable | Where-Object { $_.Index -eq $index }

        [INT]$i = 0
        Clear-Host
    }


    if (($result.media_type -eq "series") -or ($NULL -ne $seriesID)) {
        $id = if ($NULL -ne $seriesID) { $seriesID }else { $result.id }
        $seasons = Seasons -seriesID $id
        $seasonsTable = $seasons.items
        if ($Null -eq $seasonsTable) {
            Write-Host "No seasons found" -ForegroundColor Red
            break
        }
        foreach ($title in $seasonsTable) {
            $i++
            $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
        }
        $seasonsTable | Format-Table 'Index', 'title', 'episode_count', 'id', 'season_number' -AutoSize
        $index = Read-Host "Select Index"
        $result = $seasonsTable | Where-Object { $_.Index -eq $index }
        foreach ($season in $seasons.items) {
            if ($season.id -eq $result.id) {
                $media = $season
            }
        }
    }
    elseif ($result.media_type -eq "movie_listing") {
        $movies = Movies -moviesID $result.id
        $moviesTable = $movies.movies
        if ($Null -eq $moviesTable) {
            Write-Host "No movies found" -ForegroundColor Red
            break
        }
        foreach ($title in $moviesTable) {
            $i++
            $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
        }
        $moviesTable | Format-Table 'Index', 'title', 'episode_count', 'id', 'season_number' -AutoSize
        $index = Read-Host "Select Index"
        $result = $moviesTable | Where-Object { $_.Index -eq $index }
        foreach ($movie in $seasons.items) {
            if ($movie.id -eq $result.id) {
                $media = $movie
            }
        }
    }
    elseif ($NULL -eq $episodeID) {
        Write-Host "Media type not supported. $($result.media_type) | $($result)" -ForegroundColor Red
        break
    }


    [INT]$i = 0
    Clear-Host

    if ($Null -ne $episodeID) {
        $streams = Streams -mediaID $episodeID
        if ($Null -eq $streams) {
            Write-Host "No streams found" -ForegroundColor Red
            break
        }
        $streamsTable = $streams.streams
        foreach ($title in $streamsTable) {
            $i++
            $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
        }
        Do {
            Clear-Host
            $streamsTable | Format-Table 'Index', 'audio_locale', 'hardsub_locale', 'type' -AutoSize
            $index = Read-Host "Select Index (exit to quit)"
            if ($index.ToLower() -eq "exit") { break }
            $stream = $streams.streams | Where-Object { $_.Index -eq $index }
    

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
                foreach ($title in $subtitles) {
                    $i++
                    $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
                }
                $subtitles | Format-Table 'Index', 'locale' -AutoSize
                $index = Read-Host "Select Index (exit to quit)"
                if ($index.ToLower() -eq "exit") { break }
                $subtitle = $subtitles | Where-Object { $_.Index -eq $index }
                Invoke-WebRequest -Uri $subtitle.url -OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\Unknown Series\$episodeName\[$($subtitle.locale)] $episodeName.ass"
            }
            #m3u8-Downloader $stream.url
            Write-Host $stream.url
            Invoke-WebRequest -UseBasicParsing –Uri $stream.url –OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\Unknown Series\$episodeName\$episodeName.m3u8"
            Invoke-Item "$env:USERPROFILE\Desktop\Kamyroll\anime\Unknown Series\$episodeName"    
        }
        While ($true)
    }
    else {
        $mediaTable = $media.episodes
        if ($Null -eq $mediaTable) {
            Write-Host "No episodes found" -ForegroundColor Red
            break
        }
        foreach ($title in $mediaTable) {
            $i++
            $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
        }
        Do {
            #Clear-Host
            $mediaTable | Format-Table 'Index', 'title', 'episode', 'id' -AutoSize
            $index = Read-Host "Select Index (exit to quit)"
            if ($index.ToLower() -eq "exit") { break }
            $episode = $media.episodes | Where-Object { $_.Index -eq $index }

            [INT]$i = 0
            Clear-Host
    
            $streams = Streams -mediaID $episode.id
            if ($Null -eq $streams) {
                Write-Host "No streams found" -ForegroundColor Red
                break
            }
            $streamsTable = $streams.streams
            foreach ($title in $streamsTable) {
                $i++
                $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
            }
            $streamsTable | Format-Table 'Index', 'audio_locale', 'hardsub_locale', 'type' -AutoSize
            $index = Read-Host "Select Index (exit to quit)"
            if ($index.ToLower() -eq "exit") { break }
            $stream = $streams.streams | Where-Object { $_.Index -eq $index }

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
                foreach ($title in $subtitles) {
                    $i++
                    $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
                }
                $subtitles | Format-Table 'Index', 'locale' -AutoSize
                $index = Read-Host "Select Index (exit to quit)"
                if ($index.ToLower() -eq "exit") { break }
                $subtitle = $subtitles | Where-Object { $_.Index -eq $index }
                Invoke-WebRequest -Uri $subtitle.url -OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)\[$($subtitle.locale)] $($episode.title).ass"
            }
            # $url is the url with chosen resolution
            Invoke-WebRequest -UseBasicParsing –Uri $url –OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)\$($episode.title).m3u8"
            Invoke-Item "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)"
        }
        While ($true)
    }

    $Host.UI.RawUI.WindowTitle = $oldTitle

    Remove-Variable * -ErrorAction SilentlyContinue
}
Kamyroll