# Kamyroll PWSH Script
$apiUrl = "https://api.kamyroll.tech"
$deviceID = "com.service.data"
$deviceType = "powershellapi_sorryforthespam_willfixsoon"
$accessToken = "HMbQeThWmZq4t7w"

Function Get-ApiToken {
    #   Token
    # access_token
    # token_type
    # expires_in
    Function New-Token {
        $newToken = Invoke-RestMethod -Method Post -Uri "$apiUrl/auth/v1/token" -Body @{
            "device_id" = $deviceID
            "device_type" = $deviceType
            "access_token" = $accessToken
        }
        New-Item -Path "$env:USERPROFILE\Desktop\Kamyroll\token" -Name "access_token" -Value $newToken.access_token -Force
        New-Item -Path "$env:USERPROFILE\Desktop\Kamyroll\token" -Name "token_type" -Value $newToken.token_type -Force
        New-Item -Path "$env:USERPROFILE\Desktop\Kamyroll\token" -Name "expires_in" -Value $newToken.expires_in -Force
        New-Item -Path "$env:USERPROFILE\Desktop\Kamyroll\token" -Name "created_at" -Value $unixTimeStamp -Force
        return $newToken
    }
    $date = Get-Date
    $unixTimeStamp = ([DateTimeOffset]$date).ToUnixTimeSeconds()
    if(Test-Path -Path "$env:USERPROFILE\Desktop\Kamyroll\token"){
        $expiresIn = Get-Content -Path "$env:USERPROFILE\Desktop\Kamyroll\token\expires_in"
        if($unixTimeStamp -ge $expiresIn){
            $token = (New-Token).access_token
        }
        else {
            $token = Get-Content -Path "$env:USERPROFILE\Desktop\Kamyroll\token\access_token"
        }
    }
    else {
        $token = (New-Token).access_token
    }
    return $token
}

Function Search([STRING]$query,[STRING]$locale = $Null,[INT]$limit = 10,[STRING]$channel = "crunchyroll") {
    $token = Get-ApiToken
    $tokenType = Get-Content -Path "$env:USERPROFILE\Desktop\Kamyroll\token\token_type"
    if($Null -eq $query) {$query = Read-Host "Search"}
    $res = Invoke-RestMethod -Method Get -Uri "$apiUrl/content/v1/search" -Headers @{
        "authorization" = "$tokenType $token"
    } -Body @{
        "channel_id" = $channel
        "query" = $query
        "limit" = $limit
        "locale" = $locale
    }
    return $res
}

Function Seasons([STRING]$seriesID,[STRING]$channel = "crunchyroll",[STRING]$filter,[STRING]$locale) {
    $token = Get-ApiToken
    $tokenType = Get-Content -Path "$env:USERPROFILE\Desktop\Kamyroll\token\token_type"
    $res = Invoke-RestMethod -Method Get -Uri "$apiUrl/content/v1/seasons" -Headers @{
        "authorization" = "$tokenType $token"
    } -Body @{
        "channel_id" = $channel
        "id" = $seriesID
        "filter" = $filter
        "locale" = $locale
    }
    return $res
}

Function Movies([STRING]$moviesID,[STRING]$channel = "crunchyroll",[STRING]$filter,[STRING]$locale) {
    $token = Get-ApiToken
    $tokenType = Get-Content -Path "$env:USERPROFILE\Desktop\Kamyroll\token\token_type"
    $res = Invoke-RestMethod -Method Get -Uri "$apiUrl/content/v1/movies" -Headers @{
        "authorization" = "$tokenType $token"
    } -Body @{
        "channel_id" = $channel
        "id" = $moviesID
        "locale" = $locale
    }
    return $res
}

Function Media([STRING]$mediaID, [STRING]$channel = "crunchyroll", [STRING]$locale){
    $token = Get-ApiToken
    $tokenType = Get-Content -Path "$env:USERPROFILE\Desktop\Kamyroll\token\token_type"
    $res = Invoke-RestMethod -Method Get -Uri "$apiUrl/content/v1/media" -Headers @{
        "authorization" = "$tokenType $token"
    } -Body @{
        "channel_id" = $channel
        "id" = $mediaID
        "locale" = $locale
    }
    return $res
}

Function Platforms{
    $token = Get-ApiToken
    $tokenType = Get-Content -Path "$env:USERPROFILE\Desktop\Kamyroll\token\token_type"
    $res = Invoke-RestMethod -Method Get -Uri "$apiUrl/auth/v1/platforms" -Headers @{
        "authorization" = "$tokenType $token"
    }
    return $res
}

Function Streams([STRING]$mediaID, [STRING]$channel = "crunchyroll", [STRING]$format, [STRING]$type){
    # format: Subtitle Format [ass vtt srt]
    # type: Stream Type 
    # Type	                Description
    # adaptive_hls	        m3u8 format             <-(Default)
    # adaptive_dash	        dash format
    # drm_adaptive_dash	    dash format with drm
    $token = Get-ApiToken
    $tokenType = Get-Content -Path "$env:USERPROFILE\Desktop\Kamyroll\token\token_type"

    $res = Invoke-RestMethod -Method Get -Uri "$apiUrl/videos/v1/streams" -Headers @{
        "authorization" = "$tokenType $token"
    } -Body @{
        "id" = $mediaID
        "channel_id" = $channel
        "format" = $format
        "type" = $type
    }    
    return $res
}





# ABOVE HERE API BELOW HERE USAGE #





Function main{
    Clear-Host
    $query = Read-Host "Search"
    $searchResult = Search -query $query -limit 5
    [INT]$totalResults = 0
    foreach($type in $searchResult.items){
        foreach($entry in $type.items){
            $i++
        }
        $totalResults = $i
    }
    $i = 0
    Write-Host "Total Search Result: $($totalResults)`r`n" -ForegroundColor Green
    $resultTable = $searchResult.items | Select-Object -ExpandProperty items | Select-Object -Property title, id, media_type
    foreach($title in $resultTable){
        $i++
        $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
    }
    $resultTable | Format-Table 'Index', 'title', 'media_type', 'id' -AutoSize
    $index = Read-Host "Select Index"
    $result = $resultTable | Where-Object {$_.Index -eq $index}

    $i = 0
    Clear-Host

    if($result.media_type -eq "series"){
        $seasons = Seasons -seriesID $result.id
        $seasonsTable = $seasons.items
        foreach($title in $seasonsTable){
            $i++
            $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
        }
        $seasonsTable | Format-Table 'Index', 'title', 'episode_count', 'id', 'season_number' -AutoSize
        $index = Read-Host "Select Index"
        $result = $seasonsTable | Where-Object {$_.Index -eq $index}
        foreach($season in $seasons.items){
            if($season.id -eq $result.id){
                $media = $season
            }
        }
    } elseif($result.media_type -eq "movie_listing"){
        $movies = Movies -moviesID $result.id
        $moviesTable = $movies.movies
        foreach($title in $moviesTable){
            $i++
            $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
        }
        $moviesTable | Format-Table 'Index', 'title', 'episode_count', 'id', 'season_number' -AutoSize
        $index = Read-Host "Select Index"
        $result = $moviesTable | Where-Object {$_.Index -eq $index}
        foreach($movie in $seasons.items){
            if($movie.id -eq $result.id){
                $media = $movie
            }
        }
    } else {
        Write-Host "Media type not supported. $($result.media_type) | $($result)" -ForegroundColor Red
        break
    }

    $i = 0
    Clear-Host

    $mediaTable = $media.episodes
    foreach($title in $mediaTable){
        $i++
        $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
    }
    $mediaTable | Format-Table 'Index', 'title', 'episode', 'id' -AutoSize
    $index = Read-Host "Select Index"
    $episode = $media.episodes | Where-Object {$_.Index -eq $index}

    $i = 0
    Clear-Host
    
    $streams = Streams -mediaID $episode.id
    $streamsTable = $streams.streams
    foreach($title in $streamsTable){
        $i++
        $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
    }
    $streamsTable | Format-Table 'Index', 'audio_locale', 'hardsub_locale', 'type' -AutoSize
    $index = Read-Host "Select Index"
    $stream = $streams.streams | Where-Object {$_.Index -eq $index}
    $stream.url

    $i = 0
    Clear-Host

    if($stream.hardsub_locale -eq ""){
        $subtitles = $streams.subtitles
        foreach($title in $subtitles){
            $i++
            $title | Add-Member -MemberType NoteProperty -Name "Index" -Value $i
        }
        $subtitles | Format-Table 'Index', 'locale' -AutoSize
        $index = Read-Host "Select Index"
        $subtitle = $subtitles | Where-Object {$_.Index -eq $index}
        $softsub = Invoke-WebRequest -Uri $subtitle.url
        if(!(Test-Path -Path "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)")){ 
            mkdir "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)" | Out-Null
        }
        New-Item -Path "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)\[$($subtitle.locale)] $($episode.title).ass" -Value $softsub -Force | Out-Null
    }
    Invoke-WebRequest -UseBasicParsing –Uri $stream.url –OutFile "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)\$($episode.title).m3u8"
    Invoke-Item "$env:USERPROFILE\Desktop\Kamyroll\anime\$($media.title.replace(" ", "-"))\$($episode.episode)"
}

main